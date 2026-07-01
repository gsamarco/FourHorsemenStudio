# Red-team finding #1 — the VPN pre-shared key must not deploy with the committed
# placeholder or an empty value. Enforcement is gateway-conditional: it only fires
# when enable_gateway = true, so plan-only / gateway-off runs (and the CI plan
# stage, which supplies no PSK) are never blocked. Mocked providers: $0, no creds.

mock_provider "azurerm" {}
mock_provider "random" {}

variables {
  subscription_id = "00000000-0000-0000-0000-000000000000"
}

run "rejects_placeholder_psk_when_gateway_enabled" {
  command = plan
  variables {
    enable_gateway = true
    vpn_shared_key = "lab-placeholder-psk-change-me"
  }
  expect_failures = [var.vpn_shared_key]
}

run "rejects_empty_psk_when_gateway_enabled" {
  command = plan
  variables {
    enable_gateway = true
    vpn_shared_key = ""
  }
  expect_failures = [var.vpn_shared_key]
}

run "accepts_real_psk_when_gateway_enabled" {
  command = plan
  variables {
    enable_gateway = true
    vpn_shared_key = "a-genuinely-random-32char-lab-secret-value"
  }
  assert {
    condition     = var.vpn_shared_key != "lab-placeholder-psk-change-me"
    error_message = "a real PSK should pass validation when the gateway is enabled."
  }
}

# The pipeline-safe path: gateway off, no PSK supplied -> must NOT be blocked.
run "gateway_off_allows_empty_psk" {
  command = plan
  variables {
    enable_gateway = false
    vpn_shared_key = ""
  }
  assert {
    condition     = var.enable_gateway == false
    error_message = "gateway-off plans must never require a PSK (CI plan stage supplies none)."
  }
}
