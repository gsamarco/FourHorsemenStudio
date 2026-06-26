# ===========================================================================
# FourHorsemen Studio — Phase A: Hub-and-Spoke + VNet Peering
# ---------------------------------------------------------------------------
# AZ-700 Domain 1 (core networking: peering + routing). Creates a HUB VNet and
# peers the existing FourHorsemen VNet to it as a SPOKE.
#
# Peering rules in play:
#   - NON-TRANSITIVE: a hub does NOT auto-route spoke<->spoke. That needs a
#     firewall/NVA in the hub + UDRs in each spoke (next_hop VirtualAppliance →
#     firewall) — the SAME pattern as the egress UDR in firewall.tf.
#   - BIDIRECTIONAL: peering is configured on BOTH sides (two resources below).
#   - NON-OVERLAPPING: hub 10.20.0.0/16 must not overlap the spoke 10.10.0.0/16.
#
# COST: VNet + subnet + peering are ~free (peering bills only per-GB of traffic).
# ===========================================================================

# The hub VNet — in production this holds shared services: firewall, gateway,
# DNS, Bastion. (Our firewall is plan-only, so this is the foundation for it.)
resource "azurerm_virtual_network" "hub" {
  name                = "${local.name_prefix}-hub-vnet"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  address_space       = ["10.20.0.0/16"]
  tags                = local.tags
}

resource "azurerm_subnet" "hub_shared" {
  name                 = "shared-services"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = ["10.20.1.0/24"]
}

# Peering side 1: spoke (existing VNet) -> hub
resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  name                         = "spoke-to-hub"
  resource_group_name          = azurerm_resource_group.this.name
  virtual_network_name         = azurerm_virtual_network.this.name
  remote_virtual_network_id    = azurerm_virtual_network.hub.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true # let the hub forward traffic (for the NVA/firewall pattern)
  # allow_gateway_transit / use_remote_gateways left off — no gateway deployed yet.
}

# Peering side 2: hub -> spoke (peering MUST be configured both ways)
resource "azurerm_virtual_network_peering" "hub_to_spoke" {
  name                         = "hub-to-spoke"
  resource_group_name          = azurerm_resource_group.this.name
  virtual_network_name         = azurerm_virtual_network.hub.name
  remote_virtual_network_id    = azurerm_virtual_network.this.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}
