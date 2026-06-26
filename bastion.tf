# ===========================================================================
# FourHorsemen Studio — Azure Bastion (ADMIN plane)
# ---------------------------------------------------------------------------
# Secure RDP/SSH to VMs that have NO public IP of their own. This is the
# ADMIN plane (me managing boxes) — NOT how editors connect (that's the VPN
# gateway / VDI). Gated by var.enable_bastion (default false).
# COST when ON: ~$140/mo (Basic SKU) + the Standard public IP.
# Spin up to demo admin access; flip the flag off and re-apply to destroy.
# ===========================================================================

resource "azurerm_public_ip" "bastion" {
  count = var.enable_bastion ? 1 : 0

  name                = "${local.name_prefix}-bastion-pip"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  allocation_method   = "Static" # Bastion requires a Standard + Static public IP
  sku                 = "Standard"
  tags                = local.tags
}

resource "azurerm_bastion_host" "this" {
  count = var.enable_bastion ? 1 : 0

  name                = "${local.name_prefix}-bastion"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  sku                 = "Basic"
  tags                = local.tags

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.this["AzureBastionSubnet"].id # exact-name subnet
    public_ip_address_id = azurerm_public_ip.bastion[0].id
  }
}
