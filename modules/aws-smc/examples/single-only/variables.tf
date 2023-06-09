variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-central-1"
}

variable "owners" {
  description = "AMI owners"
  type        = list(any)
  default     = ["self"]
}

variable "image_name" {
  description = "SMC image name"
  type        = string
}

variable "kms_key_arns" {
  description = "A list of KMS keys used for decrypting the licenses"
  type        = list(string)
  default     = []
}

variable "mgmt_license_arn" {
  description = "AWS SecretsManager secret where mgmt license is stored"
  type        = string
  default     = ""
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

variable "wait_for_logservers" {
  description = "Flag that specifies whether module waits for log servers"
  type        = bool
  default     = false
}

variable "logserver_count" {
  description = "Number of log servers to create"
  type        = number
  default     = 0
}
