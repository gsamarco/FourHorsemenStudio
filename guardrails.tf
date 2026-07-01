# ===========================================================================
# FourHorsemen Studio — plan-only guardrail (red-team #4)
# ---------------------------------------------------------------------------
# "PLAN-ONLY, never apply" used to live only in code comments. This turns it
# into a real, testable control: bringing any of the expensive resources into
# existence now requires an explicit, separate opt-in.
#
# WHY a precondition (not a `check` block): a precondition HARD-FAILS the run;
# a `check` block only emits a warning, which would not stop an apply.
#
# WORKFLOW NOTE: to intentionally PLAN the expensive tier (the $0 proof-of-
# correctness artifacts), pass -var="confirm_expensive_resources=true" alongside
# the enable_* flag. The pipeline never sets confirm, so a stray enable_* in
# terraform.tfvars makes the CI plan fail loudly — before the apply gate.
# ===========================================================================

variable "confirm_expensive_resources" {
  description = "Explicit opt-in before Firewall/ANF/GPU/App Gateway can be planned or applied. Leave false for the cheap live footprint; set true only when deliberately, cost-consciously working with the expensive tier."
  type        = bool
  default     = false
}

# No count/for_each -> always in the graph, so it evaluates on every run
# regardless of which enable_* flag was flipped.
resource "terraform_data" "expensive_resource_guard" {
  input = "guard"

  lifecycle {
    precondition {
      condition = !(
        (var.enable_firewall || var.enable_anf || var.enable_gpu || var.enable_appgw)
        && !var.confirm_expensive_resources
      )
      error_message = "An expensive PLAN-ONLY flag (enable_firewall / enable_anf / enable_gpu / enable_appgw) is true but confirm_expensive_resources is false. These are validated plan-only; set confirm_expensive_resources = true only when you deliberately intend to plan/apply the expensive tier and accept the cost."
    }
  }
}
