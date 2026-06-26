# ===========================================================================
# FourHorsemen Studio — Phase 1: network security groups (segmentation)
# ---------------------------------------------------------------------------
# One NSG per role subnet (editing / storage / management), generated from
# local.nsgs. Rules layer least-privilege on top of Azure's defaults.
# COST: $0 — NSGs are free.
# ===========================================================================

resource "azurerm_network_security_group" "this" {
  for_each = local.nsgs

  name                = "${local.name_prefix}-${each.key}-nsg"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = local.tags

  # Emit each rule from the role's rule list.
  dynamic "security_rule" {
    for_each = each.value.rules
    content {
      name      = security_rule.value.name
      priority  = security_rule.value.priority
      direction = security_rule.value.direction
      access    = security_rule.value.access
      protocol  = security_rule.value.protocol
      # Source port is always wildcard here -> singular field ("*" is illegal in the plural list).
      source_port_range = "*"
      # Destination uses singular for "*", plural for a real port list; each rule sets one, nulls the other.
      destination_port_range     = security_rule.value.destination_port_range
      destination_port_ranges    = security_rule.value.destination_port_ranges
      source_address_prefix      = security_rule.value.source_address_prefix
      destination_address_prefix = security_rule.value.destination_address_prefix
    }
  }
}

# Bind each NSG to its same-named subnet. Only role subnets get an NSG;
# AzureBastionSubnet / GatewaySubnet / AzureFirewallSubnet are left alone
# (Bastion manages its own; gateway/firewall subnets don't take NSGs).
resource "azurerm_subnet_network_security_group_association" "this" {
  for_each = local.nsgs

  subnet_id                 = azurerm_subnet.this[each.key].id
  network_security_group_id = azurerm_network_security_group.this[each.key].id
}
