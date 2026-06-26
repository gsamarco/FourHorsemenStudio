# FourHorsemen Studio — Remote Post-Production Platform on Azure
### Architecture & Cost Brief  ·  (fictional studio · lab / proposal)

## Scenario
FourHorsemen Studio is an Emmy-caliber, **remote-first** post-production studio. Editors,
colorists, and sound engineers work from anywhere; **all media, compute, and finishing live
in Azure** and are managed in-house. The platform must feel like a local edit bay while
keeping spend under tight control.

## Design goals
1. **Performance where it matters** — GPU + low-latency shared storage for *active* editing.
2. **Cost down by design** — on-demand GPU, tiered storage lifecycle, pay-for-what's-active.
3. **Secure access** — remote editors into the platform; locked-down admin plane.

---

## Architecture

**Compute (editing):**
- **GPU VMs, NV-series** (visualization-optimized, not the ML NC-series):
  - **Full GPU** (e.g., NVadsA10 v5, full A10) for heavy projects.
  - **Fractional GPU** (e.g., 1/6 A10) for lighter projects — Azure GPU partitioning.
- **On-demand / deallocated when idle** — an idle GPU VM is pure burn. Auto-shutdown + start-on-demand.
- Remote access via a low-latency workstation protocol (Parsec / PCoIP / HP Anyware) — *app layer, noted not built*.

**Storage (lifecycle):**
- **Active editing → Azure NetApp Files (ANF, Premium)** — high-throughput NFS/SMB; editors hit this.
- **Project wraps → migrate to Blob**; a **Lifecycle Management policy** tiers it automatically:
  - **Hot** (active review/download) → **Cool** (≥30d) → **Cold** (≥90d) → **Archive** (≥180d, offline).
- ANF stays *small* (only active projects); the long tail lives cheaply in Blob.

**Networking & access:**
- VNet with role-based subnets: **editing** (GPU VMs), **storage** (ANF delegated subnet), **management**.
- **NSGs** per subnet; **UDR/routing** for editor access paths.
- **Azure Bastion** for admin (no public IPs on VMs).
- Remote editors via **Point-to-Site VPN** (or Azure Virtual Desktop) into the VNet.

---

## Cost model (the pitch)
Designed to **minimize spend** — performance on active work, cents on the archive. Drivers & levers:

| Cost driver | Lever | Effect (approx.) |
|---|---|---|
| **GPU compute** | on-demand vs always-on; fractional vs full | always-on full A10 ≈ **$2k+/mo**; 8h×22d ≈ **$500–600/mo**; fractional far less |
| **ANF (active storage)** | size to active projects only; offload when done | Premium ≈ $0.30/GiB-mo; ~4 TiB min ≈ **$1.2k/mo** — keep it small |
| **Blob tiering** | lifecycle Hot→Cool→Cold→Archive | Archive ≈ **50–100× cheaper** than Hot; old projects cost cents |
| **Egress** | editor downloads | ≈ $0.09/GB out — model it for big media |
| **Bastion / VPN gw** | Basic tiers | ≈ **$140/mo each** |

> ⚠️ **All figures are APPROXIMATE** — region-, SKU-, and commitment-dependent, and Azure prices
> change. Validate every number with the **Azure Pricing Calculator** before any real proposal.
> The *cost-down logic* is the durable part; the exact dollars get pinned per-resource as we build.

**The one-liner:** *Performance where it matters, cents where it doesn't — costed down, not bolted on.*

---

## Build plan (Terraform · IaC · "Approach A")

| Phase | Scope | Action |
|---|---|---|
| **1 — Networking foundation** | VNet, subnets, NSGs, Bastion, routing | **APPLY** (cheap, safe, demoable) |
| **2 — Storage** | ANF capacity pool/volume + Blob lifecycle policy | **WRITE + PLAN** (don't run ANF) |
| **3 — GPU compute** | NV-series VMs, full + fractional, on-demand | **WRITE + PLAN** (don't run GPU) |
| **NetDevOps layer** | Terraform modules, remote state, CI/CD pipeline | applied to the cheap parts |

**Lab-vs-production rule:** the expensive resources (ANF, GPU VMs) are written as
**production-accurate Terraform and `plan`-only — never applied** — so we learn and demonstrate the
real IaC at **$0**. Only the cheap networking foundation is applied. Each resource gets an inline
**cost estimate** comment as we build it.
