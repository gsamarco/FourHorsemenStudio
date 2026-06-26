# ===========================================================================
# FourHorsemen Studio — Point-to-Site VPN Gateway (EDITOR access plane)
# ---------------------------------------------------------------------------
# Remote editors VPN into the VNet with their Entra identity, then reach the
# edit VMs over the VDI/remote-workstation protocol. This is the USER plane
# (distinct from Bastion's admin plane). Gated by var.enable_gateway.
# COST when ON: ~$140/mo (VpnGw1).
# *** A VNet gateway takes ~30-45 MINUTES to deploy AND to destroy. ***
# Before enabling: set var.tenant_id and verify var.vpn_aad_audience.
# ===========================================================================

resource "azurerm_public_ip" "gateway" {
  count = var.enable_gateway ? 1 : 0

  name                = "${local.name_prefix}-vpngw-pip"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.tags
}

resource "azurerm_virtual_network_gateway" "this" {
  count = var.enable_gateway ? 1 : 0

  name                = "${local.name_prefix}-vpngw"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name

  type     = "Vpn"
  vpn_type = "RouteBased"
  sku      = "VpnGw1"

  ip_configuration {
    name                          = "vnetGatewayConfig"
    subnet_id                     = azurerm_subnet.this["GatewaySubnet"].id # exact-name subnet
    public_ip_address_id          = azurerm_public_ip.gateway[0].id
    private_ip_address_allocation = "Dynamic"
  }

  # Point-to-Site: editors authenticate with their Entra identity over OpenVPN
  # (OpenVPN is required for Entra/Azure AD auth).
  vpn_client_configuration {
    address_space        = [var.vpn_client_pool] # client pool — must NOT overlap the VNet
    vpn_client_protocols = ["OpenVPN"]

    aad_tenant   = "https://login.microsoftonline.com/${var.tenant_id}/"
    aad_audience = var.vpn_aad_audience
    aad_issuer   = "https://sts.windows.net/${var.tenant_id}/"
  }

  tags = local.tags
}
