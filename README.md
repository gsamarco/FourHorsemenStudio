# 🎬 FourHorsemen Studio — Cloud Post-Production Platform on Azure

> A remote-first post-production platform, provisioned end-to-end as **Terraform infrastructure-as-code**.
> *Performance where it matters, cents where it doesn't.*

A reference-architecture lab: **production-accurate Terraform** with the expensive resources
(GPU, NetApp Files, Firewall) feature-flagged and validated **`plan`-only**, so the entire
platform is proven correct at **~$0** before any production spend.

---

## Overview

Editors, colorists, and sound engineers work from anywhere while **all media, GPU compute, and
finishing live in Azure**. The platform feels like a local edit bay while keeping spend under
tight, deliberate control — and it's all reproducible from code.

## Architecture

```
                 ┌──────────── Azure Subscription / fhs-lab-rg ────────────┐
   Remote        │                  VNet  10.10.0.0/16                      │
   editors  ──VPN/VDI──►  [ editing ]   GPU edit VMs (full + fractional A10)│──► Firewall ──► Internet
                 │        [ storage ]   Azure NetApp Files (active media)   │     (FQDN egress)
   Admin  ──Bastion──►    [ management ] jump/admin                         │
                 │        + AzureBastion / Gateway / AzureFirewall subnets  │
                 └─────────────────────────────────────────────────────────┘
                                  │ project wraps
                                  ▼
              Blob Storage  ──  lifecycle: Hot → Cool → Cold → Archive (auto)

   State: Azure Storage backend (locked, shared)   ·   Deploy: Terraform → Azure DevOps CI/CD
```

### Network
| Subnet | CIDR | Purpose |
|---|---|---|
| `editing` | 10.10.1.0/24 | GPU edit VMs |
| `storage` | 10.10.2.0/24 | Azure NetApp Files (delegated subnet) |
| `management` | 10.10.3.0/24 | admin / jump plane |
| `AzureBastionSubnet` | 10.10.4.0/26 | Bastion host |
| `GatewaySubnet` | 10.10.5.0/27 | P2S VPN gateway |
| `AzureFirewallSubnet` | 10.10.6.0/26 | Azure Firewall |

Per-subnet **NSGs** enforce least-privilege east-west segmentation (admin only via Bastion;
storage reachable only from editing).

### Compute
NV-series **A10 GPU VMs** — a full A10 for heavy color/finishing and a fractional (1/6) A10 for
proxy/review — with the NVIDIA driver extension and a nightly **auto-shutdown schedule**.

### Storage (two tiers)
- **Active editing → Azure NetApp Files** (Premium): high-throughput shared NFS, sized to active
  projects only.
- **Wrapped projects → Blob** with a **lifecycle policy** that auto-tiers Hot → Cool → Cold →
  Archive by age.

### Access & Security
- **Admin plane:** Azure Bastion (no public IPs on VMs).
- **Editor plane:** Point-to-Site VPN + VDI (pixels stream, media never leaves Azure).
- **Egress control:** Azure Firewall with **FQDN-based** rules — content-security aligned with
  MPA / TPN expectations.

## Cost-effectiveness

Designed **cost-down from the start, not optimized after the fact**:

| Lever | Effect |
|---|---|
| **Right-size the GPU** (fractional vs full A10) | ~7× cheaper for light work |
| **On-demand** (auto-deallocate idle VMs) | ~4× cheaper than always-on |
| **Tiered storage lifecycle** | Same 10 TB ≈ **$3,000/mo active vs ~$10/mo archived (~300×)** |
| **Plan-only expensive resources** | Full design proven at **~$0** |

> ⚠️ All figures are approximate (region/SKU/commitment-dependent). The cost-down **logic** is the
> durable part; exact dollars are validated against the Azure Pricing Calculator.

## Automation & IaC

- **Single source of truth** — one `locals` map generates every per-component resource via
  `for_each`. Onboarding a new edit bay or subnet is a **one-line change**, not a copy-paste.
- **Feature-flag lifecycle** — billable resources flip on/off via a boolean (`enable_*`), safe-by-
  default (off = no surprise spend).
- **Remote state** — centralized in a locked Azure Storage backend; shareable and pipeline-ready.
- **CI/CD** — the manual `fmt → validate → plan → apply` workflow runs as a gated **Azure DevOps
  pipeline** (see below); infra changes are treated like ITIL change management.

## CI/CD Pipeline (Azure DevOps)

Every push to `main` triggers a two-stage pipeline that automates the manual Terraform loop:

```
git push ──► Stage 1: Validate & Plan ──► ⏸ manual approval ──► Stage 2: Apply
             fmt · init · validate · plan       (human gate)       apply the saved plan
             (read-only — safe)                                    (the only writes happen here)
```

- **No credentials on the runner** — the pipeline authenticates to Azure as a **scoped service
  principal** (Contributor) through an Azure DevOps service connection. No `az login`, no secrets
  in the repo; the secret lives encrypted in the connection and is referenced by name.
- **Plan/apply split** — Stage 1 saves the *exact* plan as a pipeline artifact; Stage 2 applies
  that artifact, so **what's approved is what's applied** — no drift between review and execution.
- **Human approval gate** — `apply` is blocked behind a manual approval on a `production`
  environment; the reviewer reads the plan before any change reaches Azure.
- **Reproducible tooling** — the Terraform version is pinned and installed per run.

The result: a single audited, gated path for every infrastructure change — push → plan →
human approval → apply.

## Deployed vs. plan-only (Approach A)

| Component | State |
|---|---|
| VNet, role subnets, NSGs | ✅ applied |
| Hub-spoke VNet peering | ✅ applied |
| Blob storage + lifecycle policy | ✅ applied |
| Private endpoint + Private DNS (Blob) | ✅ applied |
| Monitoring — VNet flow logs, Log Analytics, Traffic Analytics, alerts | ✅ applied |
| Remote state backend (Azure Storage, locked) | ✅ applied |
| **Azure DevOps CI/CD pipeline** | ✅ **built & running** |
| Bastion / P2S VPN Gateway | 📝 written, flag-gated (demo on demand) |
| Azure Firewall · NetApp Files · GPU VMs · App Gateway + WAF · Site-to-Site VPN | 📝 written, validated `plan`-only |

## Tech stack
**Terraform** (`azurerm` ~> 4.0) · **Microsoft Azure** · Azure DevOps (CI/CD) · Bash / Azure CLI

## Roadmap
- [x] Phase 1 — networking foundation (VNet, subnets, NSGs)
- [x] Phase 2 — storage (Blob lifecycle live, ANF plan-only)
- [x] Phase 3 — GPU compute (plan-only)
- [x] Private endpoints + Private DNS · hub-spoke peering
- [x] Monitoring & observability (flow logs, Log Analytics, Traffic Analytics, alerts)
- [x] Remote state backend
- [x] Azure DevOps CI/CD pipeline (plan → approval → apply)
- [ ] Optional live Bastion / GPU demos + ANF benchmark

> Exercises all five **AZ-700** (Azure Network Engineer Associate) domains hands-on —
> core networking, connectivity, application delivery, private access, and monitoring/security.

---

*Built as a hands-on cloud + IaC reference architecture. The "vSocket-style" stand-ins and
plan-only resources keep the lab at ~$0 while demonstrating the real production pattern.*
