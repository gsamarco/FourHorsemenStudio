output "resource_group" {
  description = "Name of the resource group holding the platform."
  value       = azurerm_resource_group.this.name
}

output "vnet_id" {
  description = "Resource ID of the platform VNet."
  value       = azurerm_virtual_network.this.id
}

output "subnet_ids" {
  description = "Map of subnet name => resource ID, for later phases to reference."
  value       = { for k, s in azurerm_subnet.this : k => s.id }
}

# Guarded outputs — null when the matching flag is off (one() collapses the
# count-based 0-or-1 list to a single value or null).
output "bastion_dns_name" {
  description = "Bastion host DNS name (null when enable_bastion = false)."
  value       = one(azurerm_bastion_host.this[*].dns_name)
}

output "vpn_gateway_public_ip" {
  description = "Public IP of the VPN gateway (null when enable_gateway = false)."
  value       = one(azurerm_public_ip.gateway[*].ip_address)
}

output "firewall_private_ip" {
  description = "Firewall private IP / UDR next-hop (null when enable_firewall = false)."
  value       = one([for f in azurerm_firewall.this : f.ip_configuration[0].private_ip_address])
}

output "media_storage_account" {
  description = "Blob storage account name for wrapped/archived media."
  value       = azurerm_storage_account.archive.name
}

output "anf_volume_mount_ip" {
  description = "ANF volume mount-target IP (null when enable_anf = false)."
  value       = one(flatten(azurerm_netapp_volume.this[*].mount_ip_addresses))
}

output "gpu_vm_private_ips" {
  description = "Map of GPU edit-VM name => private IP (empty when enable_gpu = false)."
  value       = { for k, n in azurerm_network_interface.gpu : k => n.private_ip_address }
}

output "blob_private_endpoint_ip" {
  description = "Private IP the Blob account is reachable at inside the VNet."
  value       = azurerm_private_endpoint.blob.private_service_connection[0].private_ip_address
}
