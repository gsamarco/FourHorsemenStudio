# ===========================================================================
# FourHorsemen Studio — Phase C: Private Endpoint for Blob storage
# ---------------------------------------------------------------------------
# AZ-700 Domain 4 (Private access) + a slice of Domain 1 (Private DNS).
# Puts a private IP from the VNet in front of the Blob account so media traffic
# rides the private network, never the public internet. The Private DNS zone
# makes the storage FQDN resolve to that private IP for in-VNet clients.
#
# COST: ~$7/mo for the endpoint; the DNS zone + link are ~free. Applied for
# real (cheap) — destroy with the lab when done.
#
# NOTE: public network access on the storage account is intentionally LEFT ON
# for now, so this laptop keeps data-plane access to manage the container.
# Disabling it (the full hardening) is discussed separately — it requires
# managing the account from inside the network (e.g. the pipeline).
# ===========================================================================

# 1. The private DNS zone for blob private endpoints (exact name required).
resource "azurerm_private_dns_zone" "blob" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = azurerm_resource_group.this.name
  tags                = local.tags
}

# 2. Link the zone to the VNet so in-VNet clients resolve against it.
resource "azurerm_private_dns_zone_virtual_network_link" "blob" {
  name                  = "${local.name_prefix}-blob-dnslink"
  resource_group_name   = azurerm_resource_group.this.name
  private_dns_zone_name = azurerm_private_dns_zone.blob.name
  virtual_network_id    = azurerm_virtual_network.this.id
  registration_enabled  = false
  tags                  = local.tags
}

# 3. The private endpoint — a NIC with a private IP that maps to the Blob
#    account. The dns_zone_group auto-writes the A record into the zone.
resource "azurerm_private_endpoint" "blob" {
  name                = "${local.name_prefix}-blob-pe"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  subnet_id           = azurerm_subnet.this["privatelink"].id
  tags                = local.tags

  private_service_connection {
    name                           = "${local.name_prefix}-blob-psc"
    private_connection_resource_id = azurerm_storage_account.archive.id
    subresource_names              = ["blob"] # the storage sub-resource we're exposing
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "blob-dns"
    private_dns_zone_ids = [azurerm_private_dns_zone.blob.id]
  }
}
