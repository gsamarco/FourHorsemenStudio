# Red-team finding #10 — a cost circuit-breaker must exist. Budgets have no
# security-sensitive attributes, so this is a light "it plans and is monthly"
# check; the real value is that the resource exists at all. Mocked providers: $0.

mock_provider "azurerm" {}
mock_provider "random" {}

variables {
  subscription_id = "00000000-0000-0000-0000-000000000000"
}

run "monthly_budget_exists" {
  command = plan

  assert {
    condition     = azurerm_consumption_budget_resource_group.this.time_grain == "Monthly"
    error_message = "a monthly resource-group budget must exist as a spend circuit-breaker."
  }

  assert {
    condition     = azurerm_consumption_budget_resource_group.this.amount == var.monthly_budget_usd
    error_message = "the budget amount must come from var.monthly_budget_usd."
  }
}
