# ===========================================================================
# FourHorsemen Studio — Phase 1: networking foundation
# ---------------------------------------------------------------------------
# Resource group + VNet + subnets.
# COST: $0 — resource groups, VNets, and subnets are free. The billable
# pieces (Bastion ~$140/mo, VPN gateway ~$140/mo, Firewall ~$900/mo) are
# added in later steps and flagged inline where they live.
# ===========================================================================

resource "azurerm_resource_group" "this" {
  name     = "${local.name_prefix}-rg"
  location = var.location
  tags     = local.tags
}

resource "azurerm_virtual_network" "this" {
  name                = "${local.name_prefix}-vnet"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  address_space       = [local.vnet_cidr]
  tags                = local.tags
}

# Every subnet from local.subnets — add a row to the map to add a subnet.
resource "azurerm_subnet" "this" {
  for_each = local.subnets

  name                 = each.key
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [each.value.cidr]

  # Only emitted for subnets that declare a delegation (e.g. ANF storage).
  dynamic "delegation" {
    for_each = each.value.delegation == null ? [] : [each.value.delegation]
    content {
      name = "delegation"
      service_delegation {
        name = delegation.value
        actions = [
          "Microsoft.Network/networkinterfaces/*",
          "Microsoft.Network/virtualNetworks/subnets/join/action",
        ]
      }
    }
  }
}
