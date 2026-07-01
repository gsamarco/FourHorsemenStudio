# Red-team finding #6 — the media storage account must have a recovery path.
# Asserts blob versioning + soft-delete are enabled on the live (applied) account.
# Mocked providers: $0, no credentials.

mock_provider "azurerm" {}
mock_provider "random" {}

variables {
  subscription_id = "00000000-0000-0000-0000-000000000000"
}

run "media_storage_has_versioning_and_soft_delete" {
  command = plan

  assert {
    condition     = azurerm_storage_account.archive.blob_properties[0].versioning_enabled == true
    error_message = "media storage must have blob versioning enabled for recovery."
  }

  assert {
    condition     = azurerm_storage_account.archive.blob_properties[0].delete_retention_policy[0].days >= 14
    error_message = "media storage must have at least 14 days of blob soft-delete retention."
  }
}
