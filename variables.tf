variable "subscription_id" {
  description = "Azure subscription ID to deploy into. Set in terraform.tfvars (gitignored) or via the ARM_SUBSCRIPTION_ID env var. Never commit it."
  type        = string
}

variable "location" {
  description = "Azure region for all resources. Validate that NV-series GPU and Azure NetApp Files are both available + in quota here before relying on it (capacity varies by region)."
  type        = string
  default     = "East US 2"
}

variable "project" {
  description = "Short project slug used as a name prefix on every resource."
  type        = string
  default     = "fhs"
}

variable "environment" {
  description = "Deployment environment tag (lab, dev, prod)."
  type        = string
  default     = "lab"
}

variable "tags" {
  description = "Common tags applied to every resource."
  type        = map(string)
  default = {
    project = "FourHorsemenStudio"
    managed = "terraform"
    purpose = "post-production-platform"
  }
}

# ---------------------------------------------------------------------------
# Feature flags — the BILLABLE resources, OFF by default.
# Flip a flag (terraform.tfvars or -var) to bring one online. The safe
# default is "off" so a forgotten flag never costs money.
# ---------------------------------------------------------------------------
variable "enable_bastion" {
  description = "Create Azure Bastion (admin plane). ~$140/mo while on. Spin up to demo, off to destroy."
  type        = bool
  default     = false
}

variable "enable_gateway" {
  description = "Create the P2S VPN gateway (editor access plane). ~$140/mo, and ~30-45 min to deploy/destroy. Demo only."
  type        = bool
  default     = false
}

variable "enable_firewall" {
  description = "Create Azure Firewall + policy + forced-tunneling UDR. ~$900/mo. PLAN-ONLY (Approach A): flip true only to `plan`, NEVER apply."
  type        = bool
  default     = false
}

variable "enable_anf" {
  description = "Create Azure NetApp Files (account/pool/volume) for active editing. ~$1,200/mo (Premium, 4 TiB). PLAN-ONLY (Approach A): flip true to `plan`, NEVER apply."
  type        = bool
  default     = false
}

# ---- ANF sizing (only used when enable_anf = true) ------------------------
variable "anf_service_level" {
  description = "ANF performance tier: Standard | Premium | Ultra."
  type        = string
  default     = "Premium"
}

variable "anf_pool_size_tb" {
  description = "Provisioned capacity-pool size in TiB. You pay for provisioned size, not used. Minimum 1."
  type        = number
  default     = 4
}

variable "anf_volume_size_gb" {
  description = "ANF volume quota in GiB (min 100, must be <= pool size). Default 1024 (1 TiB) so it fits a cheap 1-TiB test pool."
  type        = number
  default     = 1024
}

variable "enable_gpu" {
  description = "Create the GPU edit VMs (full + fractional A10). On-demand ~$80-$565/mo each (8h/day); full A10 ~$2,340/mo always-on. PLAN-ONLY (Approach A): flip true to `plan`, never apply."
  type        = bool
  default     = false
}

# ---- Edit-VM admin access (only used when enable_gpu = true) --------------
variable "admin_username" {
  description = "Admin username for the GPU edit VMs."
  type        = string
  default     = "azureadmin"
}

variable "admin_ssh_public_key" {
  description = "SSH public key for the edit VMs' admin user. Required when enable_gpu = true (pass your ~/.ssh/*.pub). Empty default is fine while GPU is off."
  type        = string
  default     = ""
}

variable "alert_email" {
  description = "Email for monitoring alerts (Action Group). Set to your address; empty = alert fires but notifies no one."
  type        = string
  default     = ""
}

variable "enable_appgw" {
  description = "Create the Application Gateway + WAF (review-portal front door). WAF_v2 ~$250+/mo. PLAN-ONLY (Approach A): flip true to `plan`, never apply."
  type        = bool
  default     = false
}

variable "vpn_shared_key" {
  description = "Pre-shared key (PSK) for the Site-to-Site IPsec tunnel. Lab placeholder; in production source from Key Vault and never commit a real key."
  type        = string
  default     = "lab-placeholder-psk-change-me"
  sensitive   = true
}

# ---- P2S VPN client config (only needed when enable_gateway = true) -------
variable "vpn_client_pool" {
  description = "Address pool handed to remote VPN clients. MUST NOT overlap the VNet (10.10.0.0/16)."
  type        = string
  default     = "172.16.0.0/24"
}

variable "tenant_id" {
  description = "Entra (Azure AD) tenant ID for P2S VPN auth. Required only when enable_gateway = true."
  type        = string
  default     = ""
}

variable "vpn_aad_audience" {
  description = "Application ID of the Azure VPN Client app, used as the Entra audience. VERIFY against current Microsoft docs — this GUID differs between the legacy manually-registered and the newer auto-registered app models."
  type        = string
  default     = "c632b3df-fb67-4d84-bbcf-9d6bd2e85a30"
}
