locals {

  smc_base      = "/usr/local/forcepoint/smc"
  smc_bin       = join("/", [local.smc_base, "bin"])
  tmp_provision = "/run/smc-provision" # avoid /tmp in cloudinit

  smc_backup_local_path = "/home/ubuntu/smc_backup"
  smc_backup_name       = join("/", [local.smc_backup_local_path, "sgm_backup_after_provision.zip"])


  #stuff related to modifying smcstarter.xml
  xml_base     = "sudo xmlstarlet edit -O -L"
  smc_xml_file = join("/", [local.smc_base, "data/smc_starter.xml"])
  log_xml_file = join("/", [local.smc_base, "data/log_starter.xml"])

  #stuff that we need to exec if we need to inject any new param.
  xml_insert_vmargs = "${local.xml_base} -i /smc_starter/server -t elem -name vmargs"
  xml_insert_mode   = "${local.xml_base} -s /smc_starter/vmargs -t attr -name mode -v append"

  insert_opt_base_mgmgt = "${local.xml_insert_vmargs} ${local.smc_xml_file} && ${local.xml_insert_mode} ${local.smc_xml_file}"
  insert_opt_base_log   = "${local.xml_insert_vmargs} ${local.log_xml_file} && ${local.xml_insert_mode} ${local.log_xml_file}"

  xml_param_add = "${local.xml_base} -s /smc_starter/vmargs -t elem -name parameter -v"

  yourkit_default_options = ["-agentpath:${local.smc_base}/libexec/libyjpagent.so=dir=${local.smc_base}/tmp", "logdir=${local.smc_base}/tmp"]

  yourkit_options = concat(local.yourkit_default_options)

  yourkit_param_extra = concat([join(",", local.yourkit_options), ["-Dyklauncher"]])


  log4j_rce_patch    = ["-Dlog4j2.formatMsgNoLookups=true"]
  mgmt_server_vmargs = concat(var.mgmt_server_vmargs, local.log4j_rce_patch)
  cloud_init_path    = join("/", [path.module, "cloudinit"])
  #values used in cloudinit templates variables
  cloudinit_values = {
    smc_base                 = local.smc_base
    smc_bin                  = local.smc_bin
    sg_data                  = "${local.smc_base}/data"
    smc_xml_file             = local.smc_xml_file
    smc_ini_provisioning     = "${local.smc_base}/tmp/sgNewProvision.ini"
    log_xml_file             = local.log_xml_file
    xml_base                 = local.xml_base
    insert_opt_base_mgmt     = local.insert_opt_base_mgmgt
    insert_opt_base_log      = local.insert_opt_base_log
    xml_param_add            = local.xml_param_add
    tmp_provision            = local.tmp_provision
    replace_script_content   = base64gzip(file(join("/", [local.cloud_init_path, "replace_or_add_in_file.sh"])))
    create_server_content    = base64gzip(file(join("/", [local.cloud_init_path, "add_server.py"])))
    wait_mgmt_primary        = base64gzip(file(join("/", [local.cloud_init_path, "wait_mgmt_primary.sh"])))
    wait_server_started      = base64gzip(file(join("/", [local.cloud_init_path, "wait_for_server_started.sh"])))
    SGConfiguration_entries  = var.SGConfiguration_entries
    LogConfiguration_entries = var.LogServerConfiguration_entries
    username                 = var.username
    password                 = var.password
    api_client_username      = var.api_client_username
    optional_perf_flag       = ""
    rest_api_port            = var.rest_api_port
    webswing_port            = var.webswing_port
    sm_current_region        = data.aws_region.current.name
    #sm_cert_arn              = local.certificate_secret_arn
    mgmt_server_xmx_memory   = var.mgmt_server_xmx_memory
    log_server_xmx_memory    = var.log_server_xmx_memory
    mgmt_server_vmargs       = var.yourkit_agent ? concat(local.mgmt_server_vmargs, flatten(local.yourkit_param_extra)) : local.mgmt_server_vmargs
    log_server_vmargs        = concat(var.log_server_vmargs, local.log4j_rce_patch)
    es_cluster_address       = var.es_cluster_address
    es_cluster_options       = var.es_cluster_options
    package_upgrade          = var.package_upgrade
    clone_web_apps           = join(" ", var.clone_web_apps)
    smc_python_version       = "1.0.8"
    quick_apikey             = var.quick_apikey,
    logserver_local          = var.logserver_local
  }
}

data "template_cloudinit_config" "mgmt_primary" {
  gzip          = false
  base64_encode = false
  part {
    content = templatefile(join("/", [local.cloud_init_path, "common.yaml.tmpl"]), local.cloudinit_values)
  }
  part {
    content = templatefile(join("/", [local.cloud_init_path, "mgmt_common.yaml.tmpl"]), local.cloudinit_values)
  }
  part {
    content = templatefile(join("/", [local.cloud_init_path, "mgmt_primary.yaml.tmpl"]),
      merge(local.cloudinit_values,
        {
          topic_arn = aws_sns_topic.primary_status_update.arn
        }
    ))
  }
}
data "template_cloudinit_config" "mgmt_replica" {
  count         = var.replica_count
  gzip          = false
  base64_encode = false
  part {
    content = templatefile(join("/", [local.cloud_init_path, "common.yaml.tmpl"]), local.cloudinit_values)
  }
  part {
    content = templatefile(join("/", [local.cloud_init_path, "mgmt_common.yaml.tmpl"]), local.cloudinit_values)
  }
  part {
    content = templatefile(join("/", [local.cloud_init_path, "mgmt_replica.yaml.tmpl"]),
      merge(local.cloudinit_values,
        {
          binding_index     = count.index + 2 #first replica is BINDING2 in license
          standby_name      = "smc-vm-${count.index + 1}"
          primary_ip        = local.primary_private_ip
          primary_hostname  = local.primary_hostname
          primary_instance  = local.primary_instance
          existing_location = var.existing_replica_location
          queue_url         = aws_sqs_queue.replica_status_update[count.index].id
        }
    ))
  }
}

data "template_cloudinit_config" "log" {
  count         = var.logserver_count
  gzip          = false
  base64_encode = false
  part {
    content = templatefile(join("/", [local.cloud_init_path, "common.yaml.tmpl"]), local.cloudinit_values)
  }
  part {
    content = templatefile(join("/", [local.cloud_init_path, "log.yaml.tmpl"]),
      merge(local.cloudinit_values,
        {
          # Name formatting of log server is very important since
          # used in add_server.py to clean log server created at
          # same time as management server.
          log_name         = "Logserver-${count.index}"
          primary_ip       = local.primary_private_ip
          primary_hostname = local.primary_hostname
          primary_instance = local.primary_instance
          queue_url        = aws_sqs_queue.log_status_update[count.index].id
    }))
  }
}
