# ===========================================================================
# FourHorsemen Studio — Phase 3: GPU edit VMs (ACTIVE editing compute)
# ---------------------------------------------------------------------------
# NV-series A10 VMs for editors. Demonstrates BOTH compute cost levers:
#   1. RIGHT-SIZE  -> two SKUs from local.gpu_vms (full A10 vs 1/6 A10)
#   2. ON-DEMAND   -> azurerm_dev_test_global_vm_shutdown_schedule deallocates
#                     them nightly so an idle GPU isn't pure burn.
#
# Gated by var.enable_gpu (default false). *** PLAN-ONLY (Approach A) ***
# Flip the flag + pass your SSH key to `terraform plan`, capture the output,
# then flip it back. NEVER apply (a full A10 always-on is ~$2,340/mo).
#
# OS is Ubuntu as a stand-in (same "keep the pattern" approach as the Cato
# lab). Production swaps a Windows + creative-apps marketplace image at the
# SAME size/NIC/subnet — a config change, not a redesign.
# ===========================================================================

resource "azurerm_network_interface" "gpu" {
  for_each = var.enable_gpu ? local.gpu_vms : {}

  name                = "${local.name_prefix}-edit-${each.key}-nic"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = local.tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.this["editing"].id # inherits the editing NSG
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "this" {
  for_each = var.enable_gpu ? local.gpu_vms : {}

  name                  = "${local.name_prefix}-edit-${each.key}"
  location              = azurerm_resource_group.this.location
  resource_group_name   = azurerm_resource_group.this.name
  size                  = each.value.vm_size # the right-size lever
  admin_username        = var.admin_username
  network_interface_ids = [azurerm_network_interface.gpu[each.key].id]

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.admin_ssh_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  tags = local.tags
}

# The ON-DEMAND lever: auto-deallocate nightly so idle GPUs don't burn money.
resource "azurerm_dev_test_global_vm_shutdown_schedule" "this" {
  for_each = var.enable_gpu ? local.gpu_vms : {}

  virtual_machine_id    = azurerm_linux_virtual_machine.this[each.key].id
  location              = azurerm_resource_group.this.location
  enabled               = true
  daily_recurrence_time = "1900"
  timezone              = "Eastern Standard Time"

  notification_settings {
    enabled = false
  }
}

# A GPU VM is inert without its driver — installed via a VM extension.
resource "azurerm_virtual_machine_extension" "gpu_driver" {
  for_each = var.enable_gpu ? local.gpu_vms : {}

  name                       = "nvidia-gpu-driver"
  virtual_machine_id         = azurerm_linux_virtual_machine.this[each.key].id
  publisher                  = "Microsoft.HpcCompute"
  type                       = "NvidiaGpuDriverLinux"
  type_handler_version       = "1.6" # verify current version before a real apply
  auto_upgrade_minor_version = true
  tags                       = local.tags
}
