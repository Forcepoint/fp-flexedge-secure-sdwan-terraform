# aws-smc module
Terraform module to deploy SMC servers.
Only works with UIID SMC Licensing on 6.8.0+ SMC versions.

These examples are provided as-is and the support is best effort based.

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | n/a |
| <a name="provider_dns"></a> [dns](#provider\_dns) | n/a |
| <a name="provider_null"></a> [null](#provider\_null) | n/a |
| <a name="provider_template"></a> [template](#provider\_template) | n/a |
| <a name="provider_time"></a> [time](#provider\_time) | n/a |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_namespace"></a> [namespace](#input\_namespace) | Common prefix for created resource names | `string` | n/a | yes |
| <a name="input_password"></a> [password](#input\_password) | Admin password for SMC | `string` | n/a | yes |
| <a name="input_smc_ami_id"></a> [smc\_ami\_id](#input\_smc\_ami\_id) | SMC AMI to deploy | `string` | n/a | yes |
| <a name="input_sshkey"></a> [sshkey](#input\_sshkey) | Public key file. Will be used to deploy all VMs | `string` | n/a | yes |
| <a name="input_username"></a> [username](#input\_username) | Admin username for SMC | `string` | n/a | yes |
| <a name="input_LogServerConfiguration_entries"></a> [LogServerConfiguration\_entries](#input\_LogServerConfiguration\_entries) | (Optional) Parameters for LogServerConfiguration.txt | `list(string)` | `[]` | no |
| <a name="input_SGConfiguration_entries"></a> [SGConfiguration\_entries](#input\_SGConfiguration\_entries) | (Optional) Parameters for SGConfiguration.txt | `list(string)` | `[]` | no |
| <a name="input_api_client_username"></a> [api\_client\_username](#input\_api\_client\_username) | SMC api client username | `string` | `"terraform-automation"` | no |
| <a name="input_clone_web_apps"></a> [clone\_web\_apps](#input\_clone\_web\_apps) | SMC replica server will clone the config of webapps from primary mgmt srv ('smc\_api', 'webswing', etc...) | `list(string)` | `[]` | no |
| <a name="input_default_tags"></a> [default\_tags](#input\_default\_tags) | Common tags for all resources | `map(any)` | `{}` | no |
| <a name="input_disk_size_gb"></a> [disk\_size\_gb](#input\_disk\_size\_gb) | SMC Disk size (must be greater than 40GB) | `string` | `40` | no |
| <a name="input_enable_ssm"></a> [enable\_ssm](#input\_enable\_ssm) | Enable SSM agent with IAM permissions | `string` | `true` | no |
| <a name="input_existing_replica_location"></a> [existing\_replica\_location](#input\_existing\_replica\_location) | This places newly created replica servers in existing location | `string` | `""` | no |
| <a name="input_log_server_vmargs"></a> [log\_server\_vmargs](#input\_log\_server\_vmargs) | (Optional) to add JVM option in log\_starter.xml | `list(string)` | `[]` | no |
| <a name="input_log_server_xmx_memory"></a> [log\_server\_xmx\_memory](#input\_log\_server\_xmx\_memory) | (Optional) to change max memory in log\_starter.xml | `string` | `""` | no |
| <a name="input_log_vm_size"></a> [log\_vm\_size](#input\_log\_vm\_size) | VM size for log servers | `string` | `"m5.xlarge"` | no |
| <a name="input_logserver_count"></a> [logserver\_count](#input\_logserver\_count) | Number of log server to deploy (at least 1) | `number` | `1` | no |
| <a name="input_mgmt_server_vmargs"></a> [mgmt\_server\_vmargs](#input\_mgmt\_server\_vmargs) | (Optional) to add JVM option in smc\_starter.xml | `list(string)` | `[]` | no |
| <a name="input_mgmt_server_xmx_memory"></a> [mgmt\_server\_xmx\_memory](#input\_mgmt\_server\_xmx\_memory) | (Optional) to change max memory in smc\_starter.xml | `string` | `""` | no |
| <a name="input_mgmt_vm_size"></a> [mgmt\_vm\_size](#input\_mgmt\_vm\_size) | VM size for mgmt servers | `string` | `"m5.xlarge"` | no |
| <a name="input_package_upgrade"></a> [package\_upgrade](#input\_package\_upgrade) | Do apt upgrade at boot. Can add around 120s of delay in cloud-init phase | `string` | `true` | no |
| <a name="input_premium_storage"></a> [premium\_storage](#input\_premium\_storage) | Premium storage (io1) usage | `string` | `false` | no |
| <a name="input_primary_hostname"></a> [primary\_hostname](#input\_primary\_hostname) | Hostname of the pre-existing primary mgmt server. This is needed if you want to only deploy replicas. | `string` | `""` | no |
| <a name="input_replica_count"></a> [replica\_count](#input\_replica\_count) | Number of mgmt replica to deploy (up to 4) | `number` | `0` | no |
| <a name="input_rest_api_port"></a> [rest\_api\_port](#input\_rest\_api\_port) | SMC REST api port (over TLS) | `string` | `8082` | no |
| <a name="input_sshkeypriv"></a> [sshkeypriv](#input\_sshkeypriv) | Private Key file. Currently needed to wait for cloud-init to complete | `string` | `""` | no |
| <a name="input_subnet_ids"></a> [subnet\_ids](#input\_subnet\_ids) | Existing subnet IDs | `list(string)` | `[]` | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | Existing VPC ID (if empty, it will create a new VPC) | `string` | `null` | no |
| <a name="input_wait_for_logservers"></a> [wait\_for\_logservers](#input\_wait\_for\_logservers) | If set to true, module waits until log servers are ready. We need var sshkeypriv to be set | `bool` | `false` | no |
| <a name="input_quick_apikey"></a> [quick\_apikey](#input\_quick\_apikey) | Don't wait for SMC to come up before writing the apikey to secretsmanager | `bool` | `false` | no |
| <a name="input_sgroup_ingress_cidrlist"></a> [sgroup\_ingress\_cidrlist](#input\_sgroup\_ingress\_cidrlist) | CIDR list for the instances' security group.  Set to tighten security. | `list(string)` | `["0.0.0.0/0"]` | no |
| <a name="static_private_ips"></a> [static\_private\_ips](#input\_static\_private\_ips) | Static private IP addresses.  Dynamic IP addresses used if null. | `map` | `{mgmt = null, log = null}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_api_url"></a> [api\_url](#output\_api\_url) | SMC API URL |
| <a name="output_log_private_ip"></a> [log\_private\_ip](#output\_log\_private\_ip) | log private ip list |
| <a name="output_log_public_ip"></a> [log\_public\_ip](#output\_log\_public\_ip) | log public ip list |
| <a name="output_log_role_name"></a> [log\_role\_name](#output\_log\_role\_name) | log role name |
| <a name="output_mgmt_primary_private_ip"></a> [mgmt\_primary\_private\_ip](#output\_mgmt\_primary\_private\_ip) | mgmt primary private ip |
| <a name="output_mgmt_primary_public_ip"></a> [mgmt\_primary\_public\_ip](#output\_mgmt\_primary\_public\_ip) | mgmt primary public ip |
| <a name="output_mgmt_primary_role_name"></a> [mgmt\_primary\_role\_name](#output\_mgmt\_primary\_role\_name) | mgmt primary role name |
| <a name="output_mgmt_replica_private_ip"></a> [mgmt\_replica\_private\_ip](#output\_mgmt\_replica\_private\_ip) | mgmt replica private ip list |
| <a name="output_mgmt_replica_public_ip"></a> [mgmt\_replica\_public\_ip](#output\_mgmt\_replica\_public\_ip) | mgmt replica public ip list |
| <a name="output_mgmt_replica_role_name"></a> [mgmt\_replica\_role\_name](#output\_mgmt\_replica\_role\_name) | mgmt replica role name |
| <a name="output_smc_base"></a> [smc\_base](#output\_smc\_base) | Path where SMC has been installed |
| <a name="output_smc_security_group_id"></a> [smc\_security\_group\_id](#output\_smc\_security\_group\_id) | SMC security group id |
| <a name="output_webswing_password"></a> [webswing\_password](#output\_webswing\_password) | SMC Webswing password |
| <a name="output_webswing_url"></a> [webswing\_url](#output\_webswing\_url) | SMC Webswing URL |
| <a name="output_webswing_user"></a> [webswing\_user](#output\_webswing\_user) | SMC Webswing username |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->

