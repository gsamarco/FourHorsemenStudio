# Pin Terraform + provider versions so every run is reproducible.
# Commit .terraform.lock.hcl alongside this so collaborators get identical providers.
terraform {
  required_version = ">= 1.5"

  # Remote state backend — state lives in Azure Storage, not on the laptop, so
  # both this machine and (later) the CI/CD pipeline read the same source of
  # truth, with blob-lease LOCKING preventing concurrent-apply corruption.
  # NOTE: backend blocks CANNOT use variables — values must be literals.
  backend "azurerm" {
    resource_group_name  = "fhs-tfstate-rg"
    storage_account_name = "fhstfstate25087"
    container_name       = "tfstate"
    key                  = "fhs-lab.tfstate"
  }

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}
