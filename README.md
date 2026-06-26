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
- **CI/CD** — the manual `fmt → validate → plan → apply` workflow automates into an **Azure DevOps
  pipeline** with gated approvals (infra changes treated like ITIL change management).

## Deployed vs. plan-only (Approach A)

| Component | State |
|---|---|
| VNet, subnets, NSGs | ✅ applied |
| Blob storage + lifecycle | ✅ applied |
| Remote state backend | ✅ applied |
| Bastion / VPN Gateway | 📝 written, flag-gated (demo on demand) |
| Azure Firewall / NetApp Files / GPU VMs | 📝 written, validated `plan`-only |

## Tech stack
**Terraform** (`azurerm` ~> 4.0) · **Microsoft Azure** · Azure DevOps (CI/CD) · Bash / Azure CLI

## Roadmap
- [x] Phase 1 — networking foundation
- [x] Phase 2 — storage (Blob lifecycle live, ANF plan-only)
- [x] Phase 3 — GPU compute (plan-only)
- [x] Remote state backend
- [ ] Azure DevOps CI/CD pipeline
- [ ] Optional live Bastion / GPU demos

---

*Built as a hands-on cloud + IaC reference architecture. The "vSocket-style" stand-ins and
plan-only resources keep the lab at ~$0 while demonstrating the real production pattern.*
