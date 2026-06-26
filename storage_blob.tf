# ===========================================================================
# FourHorsemen Studio — Phase 2b: Blob storage + lifecycle (the LONG TAIL)
# ---------------------------------------------------------------------------
# Where wrapped projects land. A lifecycle policy tiers blobs DOWN by age:
#   Hot -> Cool (30d) -> Cold (90d) -> Archive (180d).
# COST: ~$0 to APPLY (an empty account + the policy are free — you only pay
# for stored DATA). So unlike ANF, this part is meant to be APPLIED, and the
# lifecycle policy demonstrated live at no cost.
# ===========================================================================

# Storage account names are GLOBALLY unique + 3-24 lowercase alphanumeric.
# A random suffix avoids collisions.
resource "random_string" "sa_suffix" {
  length  = 6
  special = false
  upper   = false
  numeric = true
}

resource "azurerm_storage_account" "archive" {
  name                = "${var.project}media${random_string.sa_suffix.result}"
  resource_group_name = azurerm_resource_group.this.name
  location            = var.location

  account_kind             = "StorageV2"
  account_tier             = "Standard"
  account_replication_type = "LRS" # lab: cheapest. Prod would weigh GRS/ZGRS for durability.
  access_tier              = "Hot" # new blobs start Hot; the policy ages them down.

  min_tls_version = "TLS1_2" # baseline security posture

  tags = local.tags
}

resource "azurerm_storage_container" "wrapped" {
  name                  = "wrapped-projects"
  storage_account_id    = azurerm_storage_account.archive.id
  container_access_type = "private"
}

# The lifecycle policy — free to define; it just describes when blobs move.
resource "azurerm_storage_management_policy" "lifecycle" {
  storage_account_id = azurerm_storage_account.archive.id

  rule {
    name    = "media-tiering"
    enabled = true

    filters {
      blob_types = ["blockBlob"]
    }

    actions {
      base_blob {
        # Days since last modification -> next-cheaper tier.
        tier_to_cool_after_days_since_modification_greater_than    = 30
        tier_to_cold_after_days_since_modification_greater_than    = 90
        tier_to_archive_after_days_since_modification_greater_than = 180
        # No auto-delete: masters/legal copies are kept indefinitely in Archive.
      }
    }
  }
}
