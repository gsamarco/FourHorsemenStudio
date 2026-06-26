# ===========================================================================
# FourHorsemen Studio — Phase F: Network monitoring (visibility)
# ---------------------------------------------------------------------------
# AZ-700 Domain 5 (monitoring). Enables VNet flow logs via Network Watcher —
# a record of every allowed/denied IP flow in the VNet, written to storage.
#
# NOTE: we use VNET flow logs (target_resource_id = the VNet), NOT the older
# NSG flow logs — Microsoft is retiring NSG flow logs in favor of these.
#
# Network Watcher itself is free + auto-enabled per region (Azure creates
# NetworkWatcher_<region> in the NetworkWatcherRG). We reference that one.
# COST: ~$0 — log storage is tiny; Traffic Analytics (not enabled here) would cost.
# ===========================================================================

# Dedicated storage account for flow logs (kept separate from media/state).
resource "azurerm_storage_account" "flowlogs" {
  name                     = "${var.project}flowlog${random_string.sa_suffix.result}"
  resource_group_name      = azurerm_resource_group.this.name
  location                 = var.location
  account_kind             = "StorageV2"
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"
  tags                     = local.tags
}

# Log Analytics workspace — the analysis hub. Traffic Analytics processes the
# flow logs into this workspace; you then query it with KQL / build dashboards.
# COST: free to create; billed per-GB ingested (small for a low-traffic lab).
resource "azurerm_log_analytics_workspace" "this" {
  name                = "${local.name_prefix}-law"
  location            = var.location
  resource_group_name = azurerm_resource_group.this.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = local.tags
}

# VNet flow log — references the auto-created regional Network Watcher.
resource "azurerm_network_watcher_flow_log" "vnet" {
  name                 = "${local.name_prefix}-vnet-flowlog"
  network_watcher_name = "NetworkWatcher_${replace(lower(var.location), " ", "")}" # e.g. NetworkWatcher_eastus2
  resource_group_name  = "NetworkWatcherRG"

  target_resource_id = azurerm_virtual_network.this.id # VNet flow logs (not NSG)
  storage_account_id = azurerm_storage_account.flowlogs.id
  enabled            = true

  retention_policy {
    enabled = true
    days    = 7
  }

  # Traffic Analytics — processes the raw flow logs into the workspace for
  # dashboards/insights. interval 60 min = cheaper cadence (10 = more granular).
  traffic_analytics {
    enabled               = true
    workspace_id          = azurerm_log_analytics_workspace.this.workspace_id
    workspace_region      = azurerm_log_analytics_workspace.this.location
    workspace_resource_id = azurerm_log_analytics_workspace.this.id
    interval_in_minutes   = 60
  }

  tags = local.tags
}
