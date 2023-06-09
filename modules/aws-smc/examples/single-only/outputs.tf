output "mgmt_primary_public_ip" {
  description = "SMC primary public ip"
  value       = module.smc.mgmt_primary_public_ip
}
output "mgmt_replica_public_ip" {
  description = "SMC replica public ip list"
  value       = module.smc.mgmt_replica_public_ip
}
output "log_public_ip" {
  description = "log public ip list"
  value       = module.smc.log_public_ip
}
output "mgmt_primary_private_ip" {
  description = "SMC primary private ip"
  value       = module.smc.mgmt_primary_private_ip
}
output "mgmt_replica_private_ip" {
  description = "SMC replica private ip list"
  value       = module.smc.mgmt_replica_private_ip
}
output "log_private_ip" {
  description = "log private ip list"
  value       = module.smc.log_private_ip
}
output "webswing_url" {
  description = "SMC Webswing URL"
  value       = module.smc.webswing_url
}
