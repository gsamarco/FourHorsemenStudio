locals {
  # ---- Naming ------------------------------------------------------------
  name_prefix = "${var.project}-${var.environment}" # e.g. fhs-lab

  # ---- IP plan (SINGLE SOURCE OF TRUTH) ---------------------------------
  # One flat VNet for the lab. In production this VNet becomes a SPOKE that
  # peers to a hub VNet hosting the Azure Firewall, with UDRs forcing egress
  # through it (see ARCHITECTURE_BRIEF.md).
  vnet_cidr = "10.10.0.0/16"

  # Every subnet is generated from this map via for_each.
  # Onboarding a new subnet = add ONE row here.
  #
  # NOTE: AzureBastionSubnet / GatewaySubnet / AzureFirewallSubnet must use
  # those EXACT names (Azure rejects anything else) and have minimum sizes.
  subnets = {
    editing = {
      cidr       = "10.10.1.0/24" # GPU edit VMs (Phase 3, plan-only)
      delegation = null
    }
    storage = {
      cidr       = "10.10.2.0/24"             # Azure NetApp Files (Phase 2, plan-only)
      delegation = "Microsoft.Netapp/volumes" # ANF REQUIRES a delegated subnet
    }
    management = {
      cidr       = "10.10.3.0/24" # admin / jump plane
      delegation = null
    }
    AzureBastionSubnet = {
      cidr       = "10.10.4.0/26" # Bastion: /26 minimum + exact name
      delegation = null
    }
    GatewaySubnet = {
      cidr       = "10.10.5.0/27" # P2S VPN gateway: exact name required
      delegation = null
    }
    AzureFirewallSubnet = {
      cidr       = "10.10.6.0/26" # Firewall (plan-only later): /26 + exact name
      delegation = null
    }
    privatelink = {
      cidr       = "10.10.7.0/24" # dedicated subnet for private endpoints (Phase C)
      delegation = null
    }
    appgw = {
      cidr       = "10.10.8.0/24" # dedicated subnet for Application Gateway (Phase D)
      delegation = null
    }
  }

  # ---- NSG rules (per role subnet) --------------------------------------
  # Azure's DEFAULT rules already allow intra-VNet inbound and deny all
  # internet inbound. These custom rules add least-privilege on top:
  #   - admin (22/3389) ONLY from the Bastion subnet
  #   - storage reachable ONLY from editing (NFS 2049 / SMB 445), nothing else
  # Egress is intentionally left at Azure's allow-all default. Clamping
  # outbound to approved FQDNs is the Azure FIREWALL's job (Phase 2+), NOT the
  # NSG's — that gap IS the NSG-vs-firewall distinction.
  #
  # Source/dest CIDRs reference local.subnets so the IP plan stays the single
  # source of truth (no magic numbers duplicated here).
  # Port-field rule (Azure quirk): the PLURAL *_port_ranges list may NOT
  # contain "*". A wildcard must go in the SINGULAR *_port_range. So each rule
  # sets exactly one of the pair and null for the other. (source_port is always
  # "*" here, so it's hardcoded singular in nsg.tf.)
  nsgs = {
    editing = {
      rules = [
        {
          name                       = "Allow-Bastion-SSH-RDP-In"
          priority                   = 100
          direction                  = "Inbound"
          access                     = "Allow"
          protocol                   = "Tcp"
          destination_port_range     = null
          destination_port_ranges    = ["22", "3389"]
          source_address_prefix      = local.subnets["AzureBastionSubnet"].cidr
          destination_address_prefix = "*"
        },
      ]
    }
    management = {
      rules = [
        {
          name                       = "Allow-Bastion-SSH-RDP-In"
          priority                   = 100
          direction                  = "Inbound"
          access                     = "Allow"
          protocol                   = "Tcp"
          destination_port_range     = null
          destination_port_ranges    = ["22", "3389"]
          source_address_prefix      = local.subnets["AzureBastionSubnet"].cidr
          destination_address_prefix = "*"
        },
      ]
    }
    storage = {
      rules = [
        {
          name                       = "Allow-Editing-NFS-SMB-In"
          priority                   = 100
          direction                  = "Inbound"
          access                     = "Allow"
          protocol                   = "Tcp"
          destination_port_range     = null
          destination_port_ranges    = ["2049", "445"]
          source_address_prefix      = local.subnets["editing"].cidr
          destination_address_prefix = "*"
        },
        {
          name                       = "Deny-Other-Vnet-In"
          priority                   = 200
          direction                  = "Inbound"
          access                     = "Deny"
          protocol                   = "*"
          destination_port_range     = "*"
          destination_port_ranges    = null
          source_address_prefix      = "VirtualNetwork"
          destination_address_prefix = "*"
        },
      ]
    }
  }

  # ---- GPU edit VMs (Phase 3) -------------------------------------------
  # The RIGHT-SIZE cost lever, made literal: two SKUs, one map. A full A10 for
  # heavy color/finishing; a fractional (1/6) A10 for proxy/review work
  # (~7x cheaper). Add a row to add an edit bay. NV-series = visualization
  # (A10), NOT the NC-series (ML/training).
  gpu_vms = {
    heavy = {
      vm_size = "Standard_NV36ads_A10_v5" # full A10 (24 GB) — color/finishing/4K+
      role    = "full-gpu finishing"
    }
    light = {
      vm_size = "Standard_NV6ads_A10_v5" # 1/6 A10 (~4 GB) — proxy/review edits
      role    = "fractional-gpu editing"
    }
  }

  # ---- Tags -------------------------------------------------------------
  tags = merge(var.tags, { environment = var.environment })
}
