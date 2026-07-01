# Red-team finding #5 — editing/management subnets must deny other-VNet inbound,
# the same way the storage NSG already does. Runs against MOCKED providers:
# no Azure credentials, no cost, no real plan against the subscription.
#
# RED-FIRST: against the current code these assertions FAIL, because only the
# storage NSG has a Deny-Other-Vnet-In rule. Adding the rule to editing and
# management (locals.tf) flips them GREEN.

mock_provider "azurerm" {}
mock_provider "random" {}

variables {
  subscription_id = "00000000-0000-0000-0000-000000000000"
}

run "editing_nsg_denies_other_vnet_inbound" {
  command = plan

  assert {
    condition     = contains([for r in local.nsgs["editing"].rules : r.name], "Deny-Other-Vnet-In")
    error_message = "editing NSG must include a Deny-Other-Vnet-In rule, matching storage's segmentation."
  }
}

run "management_nsg_denies_other_vnet_inbound" {
  command = plan

  assert {
    condition     = contains([for r in local.nsgs["management"].rules : r.name], "Deny-Other-Vnet-In")
    error_message = "management NSG must include a Deny-Other-Vnet-In rule, matching storage's segmentation."
  }
}
