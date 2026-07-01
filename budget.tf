# ===========================================================================
# FourHorsemen Studio — cost circuit-breaker (red-team #10 / #12)
# ---------------------------------------------------------------------------
# The project's headline is cost control, but nothing in Azure actually watched
# spend. This adds a resource-group budget that fires at 50/80/100% — so a
# forgotten enable_* flag (or a GPU left running) trips an alert instead of a
# surprise invoice. FREE to deploy: a budget costs nothing; it just watches.
# ===========================================================================

variable "monthly_budget_usd" {
  description = "Monthly cost budget (USD) for the lab resource group. Sized as a circuit-breaker: well above the ~$7-20/mo live footprint, but far below the expensive tier ($900+/mo), so an accidental apply alerts fast."
  type        = number
  default     = 50
}

variable "budget_start_date" {
  description = "Budget start date, RFC3339. MUST be the first day of a month, and Azure requires it on/after the first of the CURRENT month — set it to the first of the month you deploy in."
  type        = string
  default     = "2026-07-01T00:00:00Z"
}

resource "azurerm_consumption_budget_resource_group" "this" {
  name              = "${local.name_prefix}-budget"
  resource_group_id = azurerm_resource_group.this.id

  amount     = var.monthly_budget_usd
  time_grain = "Monthly"

  time_period {
    start_date = var.budget_start_date
  }

  # Fire progressively as spend climbs. contact_roles keeps the notification
  # valid even when no alert_email is set (Azure requires at least one contact);
  # the email is added on top when var.alert_email is provided.
  dynamic "notification" {
    for_each = [50, 80, 100]
    content {
      enabled        = true
      threshold      = notification.value
      operator       = "GreaterThanOrEqualTo"
      contact_roles  = ["Owner"]
      contact_emails = var.alert_email == "" ? [] : [var.alert_email]
    }
  }
}
