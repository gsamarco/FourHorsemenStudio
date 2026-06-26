# ===========================================================================
# FourHorsemen Studio — Azure Firewall (EGRESS control / content security)
# ---------------------------------------------------------------------------
# The content-security centerpiece. NSGs segment EAST-WEST (subnet to subnet);
# this controls NORTH-SOUTH EGRESS via FQDN-based filtering — edit VMs may
# reach ONLY approved destinations, so pre-release media can't be exfiltrated.
#
# Gated by var.enable_firewall (default false).
# COST when ON: ~$900/mo+ (Standard: ~$1.25/hr base + ~$0.016/GB processed).
# (Premium tier adds IDPS + TLS inspection for more $.)
#
# *** PLAN-ONLY (Approach A) ***  Flip the flag, run `terraform plan` to
# capture proof the IaC deploys correctly, then flip it back. NEVER apply.
# ===========================================================================

resource "azurerm_public_ip" "firewall" {
  count = var.enable_firewall ? 1 : 0

  name                = "${local.name_prefix}-fw-pip"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.tags
}

resource "azurerm_firewall_policy" "this" {
  count = var.enable_firewall ? 1 : 0

  name                = "${local.name_prefix}-fw-policy"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  sku                 = "Standard"
  tags                = local.tags
}

# The egress ALLOW-LIST — the whole point. Anything not listed is denied by
# the policy's implicit default-deny, so media has nowhere to leak.
resource "azurerm_firewall_policy_rule_collection_group" "egress" {
  count = var.enable_firewall ? 1 : 0

  name               = "egress-rules"
  firewall_policy_id = azurerm_firewall_policy.this[0].id
  priority           = 500

  application_rule_collection {
    name     = "allowed-egress"
    priority = 500
    action   = "Allow"

    # Editors may reach Azure Blob (the wrapped-project / lifecycle store).
    rule {
      name = "azure-storage"
      protocols {
        type = "Https"
        port = 443
      }
      source_addresses  = [local.subnets["editing"].cidr]
      destination_fqdns = ["*.blob.core.windows.net"]
    }

    # Editing + management may reach OS update endpoints. Nothing else.
    rule {
      name = "os-updates"
      protocols {
        type = "Https"
        port = 443
      }
      source_addresses = [
        local.subnets["editing"].cidr,
        local.subnets["management"].cidr,
      ]
      destination_fqdns = ["*.windowsupdate.com", "*.update.microsoft.com"]
    }
  }
}

resource "azurerm_firewall" "this" {
  count = var.enable_firewall ? 1 : 0

  name                = "${local.name_prefix}-fw"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  sku_name            = "AZFW_VNet"
  sku_tier            = "Standard"
  firewall_policy_id  = azurerm_firewall_policy.this[0].id

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.this["AzureFirewallSubnet"].id # exact-name subnet
    public_ip_address_id = azurerm_public_ip.firewall[0].id
  }

  tags = local.tags
}

# ---- Forced tunneling: send workload egress THROUGH the firewall ----------
# Default route 0.0.0.0/0 -> firewall private IP. This is the SAME
# VirtualAppliance next-hop pattern as the Cato vSocket UDR in AzureLab —
# only here the appliance is the firewall. Storage is deliberately excluded:
# ANF has no business reaching the internet, so it gets no egress route.
resource "azurerm_route_table" "egress" {
  count = var.enable_firewall ? 1 : 0

  name                = "${local.name_prefix}-egress-rt"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = local.tags
}

resource "azurerm_route" "default_to_firewall" {
  count = var.enable_firewall ? 1 : 0

  name                   = "default-to-firewall"
  resource_group_name    = azurerm_resource_group.this.name
  route_table_name       = azurerm_route_table.egress[0].name
  address_prefix         = "0.0.0.0/0"
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = azurerm_firewall.this[0].ip_configuration[0].private_ip_address
}

resource "azurerm_subnet_route_table_association" "egress" {
  for_each = var.enable_firewall ? toset(["editing", "management"]) : toset([])

  subnet_id      = azurerm_subnet.this[each.key].id
  route_table_id = azurerm_route_table.egress[0].id
}
