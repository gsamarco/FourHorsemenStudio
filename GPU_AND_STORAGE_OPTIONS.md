# FourHorsemen Studio — GPU & Storage Options Matrix
### Performance vs. Cost decision guide  ·  (fictional · client-facing)

**Purpose:** pick the right "hardware" and storage tier *per workflow stage*, balancing
performance against cost. The platform mixes tiers deliberately — you don't pay edit-bay
prices to store a finished project.

> ⚠️ **All prices are APPROXIMATE** (US East, pay-as-you-go, mid-2026) and change frequently.
> They illustrate *relative* differences. Pin exact figures with the **Azure Pricing Calculator**
> before any real commitment. Reserved Instances / savings plans cut compute 40–60% for always-on.

---

## GPU compute (NV-series — visualization/editing, NVIDIA A10)

"On-demand" below = a realistic **8 hrs/day × 22 days = 176 hrs/mo**. "Always-on" = 730 hrs/mo.

| VM size | GPU | vCPU / RAM | ~$/hr | ~$/mo on-demand | ~$/mo always-on | Best for |
|---|---|---|---|---|---|---|
| **NV6ads A10 v5** | 1/6 A10 (~4 GB) | 6 / 55 GB | ~$0.45 | **~$80** | ~$330 | Light edits, proxy work, review sessions |
| **NV12ads A10 v5** | 1/3 A10 (~8 GB) | 12 / 110 GB | ~$0.91 | **~$160** | ~$665 | Standard editing, GFX |
| **NV36ads A10 v5** | **Full A10 (24 GB)** | 36 / 440 GB | ~$3.21 | **~$565** | ~$2,340 | Heavy color/finishing, 4K+ |
| **NV72ads A10 v5** | 2× A10 (48 GB) | 72 / 880 GB | ~$6.42 | **~$1,130** | ~$4,690 | Highest-end / multi-stream |

**The two big levers (both shown above):**
- **Fractional vs full GPU:** a 1/6 A10 is ~7× cheaper than a full A10 — match the GPU to the job.
- **On-demand vs always-on:** deallocating idle VMs is ~4× cheaper than 24/7. An idle GPU is pure burn.

*(Cheaper AMD option: NVv4 series (Radeon MI25, partitionable) for lighter VDI if A10 is overkill.)*

---

## Storage — Active editing (Azure NetApp Files / ANF)

High-throughput shared NFS/SMB for editors hitting live media. Priced on **provisioned capacity**.

| ANF tier | Throughput / TiB | ~$/GiB-mo | ~$/mo for a 4 TiB pool | Best for |
|---|---|---|---|---|
| **Standard** | ~16 MiB/s | ~$0.15 | ~$615 | Lighter active projects |
| **Premium** | ~64 MiB/s | ~$0.29 | ~$1,200 | Standard 4K editing (default) |
| **Ultra** | ~128 MiB/s | ~$0.39 | ~$1,600 | Heaviest multi-stream / DI |

> ANF is the *expensive, fast* tier — keep it sized to **active projects only**, then offload.

## Storage — Lifecycle (Azure Blob, after a project wraps)

Cheaper object storage; a **lifecycle policy** moves data down automatically as it ages.

| Blob tier | Access pattern | Min. duration | ~$/GB-mo | Retrieval | Best for |
|---|---|---|---|---|---|
| **Hot** | frequent | — | ~$0.018 | instant, cheap | Active review / downloads |
| **Cool** | infrequent | 30 days | ~$0.010 | instant, small fee | Recently-wrapped projects |
| **Cold** | rare | 90 days | ~$0.0036 | instant, higher fee | Dormant but might return |
| **Archive** | offline | 180 days | ~$0.001 | **hours to rehydrate**, high fee | Long-term legal/master copies |

**The headline contrast:** 10 TB **active on ANF Premium ≈ $3,000/mo** vs. the same 10 TB
**in Archive ≈ $10/mo.** Same data, ~300× cheaper once it's no longer being touched. *That* is the
cost-down story.

---

## Recommended mapping (the platform in one glance)

| Workflow stage | Compute | Storage | Why |
|---|---|---|---|
| **Active editing** | Full or 1/3 A10, on-demand | **ANF Premium** | Performance where it matters |
| **Client review / download** | 1/6 A10 (or none) | **Blob Hot/Cool** | Accessible, far cheaper than ANF |
| **Dormant project** | — | **Blob Cold** | Cheap, still instant if it returns |
| **Master / legal archive** | — | **Blob Archive** | Pennies; rehydrate only if needed |

**One-liner for the client:** *Performance where it matters, cents where it doesn't.*
