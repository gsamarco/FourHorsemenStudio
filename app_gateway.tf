# ===========================================================================
# FourHorsemen Studio — Phase D: Application Gateway + WAF (app delivery)
# ---------------------------------------------------------------------------
# AZ-700 Domain 3 (application delivery). An L7 web front door for the client
# REVIEW PORTAL, with a WAF (OWASP) — the one public-facing web component, and
# therefore the one place a WAF actually belongs (vs storage/editing tiers).
#
# Gated by var.enable_appgw (default false). COST when ON: WAF_v2 ~$250+/mo.
# *** PLAN-ONLY (Approach A) ***  flip the flag to `plan`, capture it, never apply.
#
# NOTE: listener is HTTP/80 to keep the lab cert-free. Production = HTTPS/443
# with a TLS cert (from Key Vault) terminating on the gateway.
# ===========================================================================

resource "azurerm_public_ip" "appgw" {
  count = var.enable_appgw ? 1 : 0

  name                = "${local.name_prefix}-appgw-pip"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.tags
}

# The WAF policy — OWASP managed ruleset in Prevention mode (actively blocks
# SQLi/XSS/etc., not just logs them).
resource "azurerm_web_application_firewall_policy" "review" {
  count = var.enable_appgw ? 1 : 0

  name                = "${local.name_prefix}-review-waf"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name

  policy_settings {
    enabled = true
    mode    = "Prevention"
  }

  managed_rules {
    managed_rule_set {
      type    = "OWASP"
      version = "3.2"
    }
  }

  tags = local.tags
}

resource "azurerm_application_gateway" "review" {
  count = var.enable_appgw ? 1 : 0

  name                = "${local.name_prefix}-review-appgw"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  firewall_policy_id  = azurerm_web_application_firewall_policy.review[0].id
  tags                = local.tags

  sku {
    name     = "WAF_v2"
    tier     = "WAF_v2"
    capacity = 1
  }

  gateway_ip_configuration {
    name      = "gateway-ip-config"
    subnet_id = azurerm_subnet.this["appgw"].id # dedicated App Gateway subnet
  }

  frontend_port {
    name = "http-port"
    port = 80
  }

  frontend_ip_configuration {
    name                 = "frontend-ip"
    public_ip_address_id = azurerm_public_ip.appgw[0].id
  }

  # Hypothetical backend: the review-portal app servers.
  backend_address_pool {
    name  = "review-portal-pool"
    fqdns = ["review-backend.fhs.example"]
  }

  backend_http_settings {
    name                  = "review-http-settings"
    cookie_based_affinity = "Disabled"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 30
  }

  http_listener {
    name                           = "review-listener"
    frontend_ip_configuration_name = "frontend-ip"
    frontend_port_name             = "http-port"
    protocol                       = "Http"
  }

  request_routing_rule {
    name                       = "review-rule"
    rule_type                  = "Basic"
    priority                   = 100
    http_listener_name         = "review-listener"
    backend_address_pool_name  = "review-portal-pool"
    backend_http_settings_name = "review-http-settings"
  }
}
