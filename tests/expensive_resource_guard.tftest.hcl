# Red-team finding #4 — "plan-only, never apply" is a real control, not a comment.
# The guard blocks any expensive flag unless confirm_expensive_resources = true.
# Mocked providers: $0, no credentials.
#
# NOTE on red-first: this finding ADDS a control (a new resource), rather than
# fixing existing code, so there's no "assert against current code and watch it
# fail" step — the resource wouldn't exist to reference. Instead these runs prove
# the guard BEHAVES: it blocks without confirmation and permits with it.

mock_provider "azurerm" {}
mock_provider "random" {}

variables {
  subscription_id = "00000000-0000-0000-0000-000000000000"
}

run "blocks_firewall_without_confirmation" {
  command = plan
  variables {
    enable_firewall             = true
    confirm_expensive_resources = false
  }
  expect_failures = [terraform_data.expensive_resource_guard]
}

run "blocks_anf_without_confirmation" {
  command = plan
  variables {
    enable_anf                  = true
    confirm_expensive_resources = false
  }
  expect_failures = [terraform_data.expensive_resource_guard]
}

run "allows_firewall_with_explicit_confirmation" {
  command = plan
  variables {
    enable_firewall             = true
    confirm_expensive_resources = true
  }
  assert {
    condition     = var.confirm_expensive_resources == true
    error_message = "explicit confirmation should let the expensive-tier plan proceed."
  }
}

run "cheap_footprint_needs_no_confirmation" {
  command = plan
  variables {
    confirm_expensive_resources = false
  }
  # No expensive flags set -> the guard must NOT block. Reaching this assert at
  # all means the plan succeeded; we assert a plan-known input (the resource's
  # computed .output isn't available until apply).
  assert {
    condition     = var.confirm_expensive_resources == false
    error_message = "the default cheap footprint must plan cleanly with no confirmation."
  }
}
