#!/usr/bin/python3
"""Declares a log/mgmt server via SMC REST api"""
import argparse
import logging
import sys
import json

from smc import session # pylint: disable=import-error
from smc.api.common import SMCRequest # pylint: disable=import-error
from smc.elements.servers import LogServer, ManagementServer, ElasticsearchCluster # pylint: disable=import-error
from smc.elements.other import Location
from smc import set_stream_logger # pylint: disable=import-error

set_stream_logger(log_level=logging.INFO)

parser = argparse.ArgumentParser(description="Add server (log, mgt, es)")
parser.add_argument('--host', dest='host', action='store')
parser.add_argument('-p', '--port', dest='port', action='store', type=int)
parser.add_argument('--secure', help='use https', action='store_true')
parser.add_argument('--cert', help='smc certificate')
parser.add_argument('--api-key')
parser.add_argument('--api-version')
parser.add_argument('--server-kind',
                    choices=["log_server", "mgt_server", "es_cluster"])
parser.add_argument('--server-name')
parser.add_argument('--server-ip')
parser.add_argument('--es-cluster-options', default="{}")
parser.add_argument('--locations', nargs="+", default=[])
parser.add_argument('--put-in-location', default=None)
parser.add_argument('--clone-web-apps', nargs="+", default=[])
parser.add_argument('--with-local-logserver',
                    help='is there a log server along with the mgmt instance',
                    action='store_true')
args = parser.parse_args()

URL = "{scheme}://{host}:{port}".format(scheme="https" if args.secure else "http",
                                        host=args.host,
                                        port=args.port)


def set_location(srv_kind, name, location_name, location_ip):
    """ Set a location on for a given server name & kind"""
    base_map = {
            "mgt_server": ManagementServer,
            "log_server": LogServer,
            "es_cluster": ElasticsearchCluster
            }
    base = base_map.get(srv_kind, None)
    if base is None:
        print("unknown srv_kind {}".format(srv_kind))
        sys.exit(1)
    base(name).add_contact_address(contact_address=location_ip,
                                   location=location_name)

def get_next_unused_license():
    """iterate over unused licenses"""
    href = "{href_base}/system/licenses".format(href_base=HREF_BASE)
    server_response = SMCRequest(href).read()
    if server_response.code >= 400:
        print("error listing licenses {}".format(server_response.msg))
        sys.exit(1)
    full_list = server_response.json['license']
    license_kind = "LOGSERVER"
    licenses = [l for l in full_list \
            if l["type"] == license_kind and l["binding_state"] == "Unassigned"]
    yield from licenses

def bind_license(server_href, free_license):
    """Bind a server with a license and returns True if successful"""
    href = "{href_base}/system/license_bind".format(href_base=HREF_BASE)
    djson = {'component_href': server_href,
             'license_item_id': free_license["license_id"]}
    server_response = SMCRequest(href, djson).create()
    if server_response.code >= 400:
        print("error binding license {}".format(server_response.msg))
        return False
    return True

def delete_mgmt_local_log(new_server_href):
    """We need to remove LogServer 127.0.0.2.
    First step is to change log Server in Mgt Server properties
    Finally we remove the Log Server. Do it only when creating Logserver-0 """
    log_srv_name_to_delete = "LogServer 127.0.0.2"
    log_servers = list(LogServer.objects.all())
    for log_server in log_servers:
        if log_server.name == log_srv_name_to_delete:
            # Log server found then we need to remove it
            # Change mgt server Log Server
            print("Deleting log server {}"
                  .format(log_srv_name_to_delete))
            try:
                management_server = ManagementServer("Management Server")
                management_server.update(alert_server_ref=new_server_href)
                log_server.delete()
                break
            except Exception as exc:
                print("Failed to update log server")
                print(exc)

def create_server(parsed_args):
    """Declare a server and bind a license to it"""
    kind = parsed_args.server_kind
    server_name = parsed_args.server_name
    server_ip = args.server_ip
    if kind == "es_cluster":
        es_extra_args = json.loads(parsed_args.es_cluster_options)
        es = ElasticsearchCluster.create(name=server_name,
                                         address=server_ip,
                                         **es_extra_args)
    else:
        clone_web_apps = args.clone_web_apps
        href = "{}/elements/{}".format(HREF_BASE, kind)
        element_json = {'name': server_name, 'address': server_ip}
        if args.put_in_location:
            ref = Location.get(name=args.put_in_location).href
            element_json['location_ref'] = ref
        if kind == 'log_server':
            element_json['channel_port'] = 3020
        if kind == 'mgt_server':
            # Get first server
            log_server_href = list(LogServer.objects.all())[0].href
            element_json['alert_server_ref'] = log_server_href
            if clone_web_apps:
                element_json['web_app'] = []
                ha_data = SMCRequest("{href_base}/ha".format(href_base=HREF_BASE)).read()
                primary_data = SMCRequest(ha_data.json['active_server']).read()
                webapps = primary_data.json['web_app']
                for app in webapps:
                    if app['web_app_identifier'] in clone_web_apps:
                        element_json['web_app'].append(app)
        server_response = SMCRequest(href, element_json).create()
        if server_response.code >= 400:
            print("error creating server: {}".format(server_response.msg))
            sys.exit(1)

        for location in parsed_args.locations:
            location_name, location_ip = location.split(':')
            set_location(kind, server_name, location_name, location_ip)
        server_href = server_response.href
        if kind == "log_server":
            # we need to bind log_server licenses manually. Mgmts are
            # UIID auto-binded
            binded = False
            free_licenses = get_next_unused_license()
            while not binded:
                free_license = next(free_licenses)
                if free_license is None:
                    print("out of free licenses")
                    sys.exit(1)
                binded = bind_license(server_href, free_license)

            """
            We need to remove LogServer 127.0.0.2.
            First step is to change log Server in Mgt Server properties
            Finally we remove the Log Server.
        
            Do it only when creating Logserver-0
            """
            if server_name == "Logserver-0":
               if parsed_args.with_local_logserver:
                   print("not deleting LogServer 127.0.0.2")
               else:
                   delete_mgmt_local_log(server_href)

session.login(url=URL, api_key=args.api_key, verify=args.cert,
              api_version=args.api_version)
HREF_BASE = "{url}/{api_version}".format(url=URL, api_version=session.api_version)
create_server(args)
session.logout()
