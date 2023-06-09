output "mgmt_primary_public_ip" {
  description = "mgmt primary public ip"
  value       = local.primary_public_ip
}
output "mgmt_primary_public_name" {
  description = "mgmt primary public name"
  value       = local.primary_hostname
}
output "mgmt_primary_private_ip" {
  description = "mgmt primary private ip"
  value       = local.primary_private_ip
}
output "mgmt_replica_public_ip" {
  description = "mgmt replica public ip list"
  value       = aws_instance.mgmt_replica.*.public_ip
}
output "mgmt_replica_public_name" {
    description = "mgmt replica public name list"
    value       = aws_instance.mgmt_replica.*.public_dns
}
output "mgmt_replica_private_ip" {
  description = "mgmt replica private ip list"
  value       = aws_instance.mgmt_replica.*.private_ip
}
output "log_public_ip" {
  description = "log public ip list"
  value       = aws_instance.log.*.public_ip
}
output "log_public_name" {
    description = "Log public name list"
    value       = aws_instance.log.*.public_dns
}
output "log_private_ip" {
  description = "log private ip list"
  value       = aws_instance.log.*.private_ip
}
output "mgmt_primary_role_name" {
  description = "mgmt primary role name"
  value       = aws_iam_role.mgmt_primary.name
}
output "mgmt_replica_role_name" {
  description = "mgmt replica role name"
  value       = aws_iam_role.mgmt_replica.name
}
output "log_role_name" {
  description = "log role name"
  value       = aws_iam_role.log.name
}
output "webswing_url" {
  description = "SMC Webswing URL"
  value       = "https://${local.primary_hostname}:8085"
}
output "webswing_user" {
  description = "SMC Webswing username"
  value       = var.username
}
output "webswing_password" {
  description = "SMC Webswing password"
  value       = var.password
}
output "smc_security_group_id" {
  description = "SMC security group id"
  value       = aws_security_group.smc.id
}
output "api_url" {
  description = "SMC API URL"
  value       = "https://${local.primary_hostname}:${var.rest_api_port}"
}
output "smc_base" {
  description = "Path where SMC has been installed"
  value       = local.smc_base
}

output "smc_backup_name" {
  description = "Name of backup and path where it is created an store after provisioning is done"
  value = local.smc_backup_name
}
