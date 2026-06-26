# ===========================================================================
# FourHorsemen Studio — Alerting (the "alarms" layer of observability)
# ---------------------------------------------------------------------------
# AZ-700 Domain 5. An Action Group (who gets notified + how) and a sample
# metric alert (egress spike on the media store = possible exfiltration —
# the content-security alert that matters most for pre-release media).
# COST: metric alert ~$0.10/mo; Action Group email is free.
# ===========================================================================

# WHO gets told, and HOW. Email receiver only added if var.alert_email is set.
resource "azurerm_monitor_action_group" "ops" {
  name                = "${local.name_prefix}-ops-ag"
  resource_group_name = azurerm_resource_group.this.name
  short_name          = "fhsops"

  dynamic "email_receiver" {
    for_each = var.alert_email == "" ? [] : [var.alert_email]
    content {
      name          = "ops-email"
      email_address = email_receiver.value
    }
  }

  tags = local.tags
}

# Sample alert: unusual OUTBOUND data from the media store → possible
# exfiltration of pre-release content. Metric-based (robust, no log dependency).
resource "azurerm_monitor_metric_alert" "media_egress" {
  name                = "${local.name_prefix}-media-egress-alert"
  resource_group_name = azurerm_resource_group.this.name
  scopes              = [azurerm_storage_account.archive.id]
  description         = "Fires on unusual outbound data from the media store (possible exfiltration)."
  severity            = 2       # 0=critical .. 4=verbose
  frequency           = "PT5M"  # evaluate every 5 min
  window_size         = "PT15M" # over a 15-min window

  criteria {
    metric_namespace = "Microsoft.Storage/storageAccounts"
    metric_name      = "Egress"
    aggregation      = "Total"
    operator         = "GreaterThan"
    threshold        = 1073741824 # 1 GiB out in 15 min — tune to taste
  }

  action {
    action_group_id = azurerm_monitor_action_group.ops.id
  }

  tags = local.tags
}
