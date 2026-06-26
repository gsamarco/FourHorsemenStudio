# azurerm v4 requires an explicit subscription_id (either here or via the
# ARM_SUBSCRIPTION_ID env var). We pass it as a variable so it's never hardcoded.
# Auth itself comes from `az login` on your machine.
provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}
