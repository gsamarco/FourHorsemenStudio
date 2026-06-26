# ===========================================================================
# FourHorsemen Studio — Phase 2a: Azure NetApp Files (ACTIVE editing storage)
# ---------------------------------------------------------------------------
# The fast, expensive tier — high-throughput shared NFS for editors hitting
# live media. Priced on PROVISIONED capacity (you pay for the pool size, used
# or not), so it's kept small and sized to active projects only.
#
# Gated by var.enable_anf (default false). COST when ON: ~$1,200/mo
# (Premium, 4 TiB). *** PLAN-ONLY (Approach A) ***  Flip the flag, run
# `terraform plan` to prove the IaC, then flip it back. NEVER apply.
#
# Hierarchy: account -> capacity pool (service level + size) -> volume.
# ===========================================================================

resource "azurerm_netapp_account" "this" {
  count = var.enable_anf ? 1 : 0

  name                = "${local.name_prefix}-anf"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = local.tags
}

resource "azurerm_netapp_pool" "this" {
  count = var.enable_anf ? 1 : 0

  name                = "${local.name_prefix}-anf-pool"
  account_name        = azurerm_netapp_account.this[0].name
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  service_level       = var.anf_service_level # this + size = what you pay for
  size_in_tb          = var.anf_pool_size_tb
  tags                = local.tags
}

resource "azurerm_netapp_volume" "this" {
  count = var.enable_anf ? 1 : 0

  name                = "${local.name_prefix}-active-media"
  account_name        = azurerm_netapp_account.this[0].name
  pool_name           = azurerm_netapp_pool.this[0].name
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  service_level       = var.anf_service_level
  volume_path         = "active-media"
  protocols           = ["NFSv3"]
  storage_quota_in_gb = var.anf_volume_size_gb # parameterized; min 100, <= pool size
  network_features    = "Standard"             # required to unlock the 1-TiB minimum pool

  # The volume lives in the DELEGATED storage subnet from Phase 1.
  subnet_id = azurerm_subnet.this["storage"].id

  # Export policy: only the editing subnet may mount this share.
  export_policy_rule {
    rule_index      = 1
    allowed_clients = [local.subnets["editing"].cidr]
    protocol        = ["NFSv3"] # renamed from protocols_enabled (removed in provider v5)
    unix_read_only  = false
    unix_read_write = true
  }

  tags = local.tags
}
