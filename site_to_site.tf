# ===========================================================================
# FourHorsemen Studio — Phase E: Site-to-Site VPN (hybrid connectivity)
# ---------------------------------------------------------------------------
# AZ-700 Domain 2. Connects an on-prem "branch studio" LAN into the platform
# via an IPsec/IKE tunnel terminating on the existing VPN gateway (gateway.tf).
# The Azure-native cousin of the Cato M&A site-onboarding pattern.
#
# Gated by var.enable_gateway (the VPN gateway must exist). PLAN-ONLY —
# the gateway is ~$140/mo + ~30-45 min to deploy.
#
# NAMING (the classic trap): Virtual Network Gateway = the AZURE side;
# Local Network Gateway = the ON-PREM ("local" datacenter) side.
# ===========================================================================

# Represents the ON-PREM branch: its public VPN IP + the LAN behind it.
resource "azurerm_local_network_gateway" "branch" {
  count = var.enable_gateway ? 1 : 0

  name                = "${local.name_prefix}-branch-lng"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  gateway_address     = "203.0.113.10"      # branch's public VPN IP (placeholder, TEST-NET-3 docs range)
  address_space       = ["192.168.50.0/24"] # the on-prem LAN behind it
}

# The IPsec tunnel: Azure VPN gateway <-> the branch (local network gateway).
resource "azurerm_virtual_network_gateway_connection" "s2s" {
  count = var.enable_gateway ? 1 : 0

  name                = "${local.name_prefix}-branch-s2s"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  type                = "IPsec"

  virtual_network_gateway_id = azurerm_virtual_network_gateway.this[0].id # Azure side
  local_network_gateway_id   = azurerm_local_network_gateway.branch[0].id # on-prem side

  shared_key = var.vpn_shared_key # PSK — in prod, source from Key Vault; never hardcode a real key
}
