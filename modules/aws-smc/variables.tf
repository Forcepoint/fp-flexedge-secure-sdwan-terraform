variable "smc_ami_id" {
  description = "SMC AMI to deploy"
  type        = string
}

variable "mgmt_vm_size" {
  description = "VM size for mgmt servers"
  type        = string
  default     = "m5.xlarge"
}

variable "log_vm_size" {
  description = "VM size for log servers"
  type        = string
  default     = "m5.xlarge"
}

variable "logserver_count" {
  description = "Number of log server to deploy (at least 1)"
  type        = number
  default     = 1
}

variable "logserver_local" {
  description = "if true start a log server in the primary mgmt EC2 instance"
  type        = bool
  default     = false
}

variable "replica_count" {
  description = "Number of mgmt replica to deploy (up to 4)"
  type        = number
  default     = 0
}

variable "default_tags" {
  description = "Common tags for all resources"
  type        = map(any)
  default     = {}
}

variable "vpc_id" {
  description = "Existing VPC ID (if empty, it will create a new VPC)"
  type        = string
  default     = null
}

variable "subnet_ids" {
  description = "Existing subnet IDs"
  type        = list(string)
  default     = []
}

variable "namespace" {
  description = "Common prefix for created resource names"
  type        = string
}

variable "kms_key_arns" {
  description = "A list of AWS KMS keys used for decrypting the licenses"
  type        = list(string)
  default     = []
}

variable "username" {
  description = "Admin username for SMC"
  type        = string
}
variable "password" {
  description = "Admin password for SMC"
  type        = string
}

variable "sshkey" {
  description = "Public key file. Will be used to deploy all VMs"
  type        = string
}
variable "sshkeypriv" {
  description = "Private Key file. Currently needed to wait for cloud-init to complete"
  type        = string
  default     = "/home/deepak/Desktop/terraform-aws-smc-master/examples/single-only/keys"
}

variable "premium_storage" {
  description = "Premium storage (io1) usage"
  type        = string
  default     = false
}

variable "disk_size_gb" {
  description = "SMC Disk size (must be greater than 40GB)"
  type        = string
  default     = 40
}

variable "api_client_username" {
  description = "SMC api client username"
  type        = string
  default     = "terraform-automation"
}

variable "rest_api_port" {
  description = "SMC REST api port (over TLS)"
  type        = string
  default     = 8082
}

variable "webswing_port" {
  description = "webswing port (over TLS)"
  type        = string
  default     = 8085
}

variable "wait_for_logservers" {
  description = "If set to true, module waits until log servers are ready. We need var sshkeypriv to be set"
  type        = bool
  default     = false
}

#SMC "debugging" variables
variable "yourkit_agent" {
  description = "Enable yourkit agent"
  type        = string
  default     = false
}

variable "SGConfiguration_entries" {
  description = "(Optional) Parameters for SGConfiguration.txt"
  type        = list(string)
  default     = []
}

variable "LogServerConfiguration_entries" {
  description = "(Optional) Parameters for LogServerConfiguration.txt"
  type        = list(string)
  default     = []
}

variable "mgmt_server_xmx_memory" {
  description = "(Optional) to change max memory in smc_starter.xml"
  type        = string
  default     = ""
}

variable "log_server_xmx_memory" {
  description = "(Optional) to change max memory in log_starter.xml"
  type        = string
  default     = ""
}

variable "mgmt_server_vmargs" {
  description = "(Optional) to add JVM option in smc_starter.xml"
  type        = list(string)
  default     = []
}

variable "log_server_vmargs" {
  description = "(Optional) to add JVM option in log_starter.xml"
  type        = list(string)
  default     = []
}

variable "es_cluster_address" {
  description = "Elasticsearch cluster address (ip or FQDN)"
  type        = string
  default     = ""
}

variable "package_upgrade" {
  description = "Do apt upgrade at boot. Can add around 120s of delay in cloud-init phase"
  type        = string
  default     = true
}

variable "primary_hostname" {
  description = "Hostname of the pre-existing primary mgmt server. This is needed if you want to only deploy replicas."
  type        = string
  default     = ""
}

variable "existing_replica_location" {
  description = "This places newly created replica servers in existing location"
  type        = string
  default     = ""
}

variable "es_cluster_options" {
  description = "Elasticsearch cluster json options, see https://github.com/Forcepoint/fp-NGFW-SMC-python/blob/master/smc/elements/servers.py#L487"
  type        = string
  default     = "{}"
}

variable "clone_web_apps" {
  description = "SMC replica server will clone the config of webapps from primary mgmt srv ('smc_api', 'webswing', etc...) "
  type        = list(string)
  default     = []
}

variable "create_smc_backup" {
  description = <<-EOT
  Set to "true" in order to generate SMC backup at the end of provisioning. Default: "false"
  EOT
  type        = bool
  default     = false
}

variable "enable_ssm" {
  description = "Enable SSM agent with IAM permissions"
  type        = string
  default     = true
}

variable "quick_apikey" {
  description = "Write apikey as soon as it is generated.  Users should be aware that SMC might not be up right away"
  type        = bool
  default     = false
}

variable "sgroup_ingress_cidrlist" {
  description = "List of CIDR blocks that are allowed access to the resources"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "static_private_ips" {
  description = <<-EOT
  Set the following keys in the map to use static private IP addresses:
    - mgmt:   if you want a static private IP for the management server
    - log:    if you want a static private IP for the log server
  Replica instances are unsupported and always get dynamic IPs.
  If multiple log servers are defined, only the first will get a static IP
  address.
  If any instance is missing the static IP, a dynamic one will be allocated.
  Public IPs are unaffected by this.
  EOT
  type    = map
  default = {
    mgmt = null
    log  = null
  }
}
