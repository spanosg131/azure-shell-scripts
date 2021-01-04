#!/bin/bash
# Description: Script that provisions Azure Blobs for storing Terraform states.
#              It is basically a spiced up version of the script found in 
#              https://docs.microsoft.com/en-us/azure/developer/terraform/store-state-in-azure-storage
# Author: Georgios Spanos

# Functions
azure_location_name() {
  echo "For up to date Azure location list 'az account list-locations'"
  echo "SES frequent Azure regions: eastus, westus, westeurope, northeurope"
  read -rp "Enter Azure region name : " azure_location_name
}
resource_group_name() {
  read -rp "Enter resource group name : " resource_group_name
}

storage_account_name() {
  read -rp "Enter storage account name : " storage_account_name
}

storage_storage_container_name() {
  read -rp "Enter container name : " storage_container_name
  echo "Container names must be uniqe accross an Azure storage account."
  echo "Adding a timestamp at the end of the desired container name will ensure uniqueness."
  echo "Days since 1970-01-01 (Unix epoch) will be used as timestamp"
  read -rp "Add a timestamp at the end of the container name [y,n]? " timestamp
  case "${timestamp}" in
    [yY][eE][sS]|[yY])
      ts=$(($(date +%s) / 60 / 60 / 24))
      storage_container_name="${storage_container_name}-${ts}"
      return 
      ;;
    *)
      return
      ;;
  esac
}

verify_input() {
  clear
  if [ -n "${azure_location_name}" ]
  then
    echo "Azure region name: ${azure_location_name}"
  fi

  if [ -n "${resource_group_name}" ]
  then
    echo "Resource group name: ${resource_group_name}"
  fi

  if [ -n "${storage_account_name}" ]
  then    
    echo "Storage account name: ${storage_account_name}"
  fi

  if [ -n "${storage_container_name}" ]
  then 
    echo "Storage container: ${storage_container_name}"
  fi
  
  read -rp "Do you want to proceed with these values [y,n,a]? " confirmation
  case "${confirmation}" in
    [yY][eE][sS]|[yY])
      create_azure_resources
      return
      ;;
     [nN][oO]|[nN])
      # this option will restart the script
      $0
      return
      ;;
    [aA][bB][oO][rR][tT]|[aA])      
      echo "Aborting script execution."
      exit 1
      ;;
    *)      
      create_azure_resources
      return
      ;;       
  esac
}

create_azure_resources() {
  echo
  echo
  # Some input validation
  if [ -z "${storage_container_name}" ] || [ -z "${storage_account_name}" ] || [ -z "${resource_group_name}" ]
  then
    echo "Missing blob container name, storage account, or resource group name. Aborting script execution."
    exit 1
  fi

  if [ "${choice}" -eq 1 ] && [ -z "${azure_location_name}" ]
  then
    echo "Missing Azure region name. Aborting script execution."
    exit 1 
  fi 
  
  if [ -n "${azure_location_name}" ] && [ -n "${resource_group_name}" ] && [ "${choice}" -eq 1 ]
  then
    echo "Creating resource group..."
    az group create --name "${resource_group_name}" --location "${azure_location_name}"
    rc=$?; if [[ $rc != 0 ]]; then exit $rc; fi
  fi

  if [ -n "${storage_account_name}" ] && [ "${resource_group_name}" ]  && { [ "${choice}" -eq 2 ] || [ "${choice}" -eq 1 ]; }
  then
    echo "Creating storage account..."
    az storage account create --resource-group "${resource_group_name}" --name "${storage_account_name}" --sku Standard_LRS --encryption-services blob
    rc=$?; if [[ $rc != 0 ]]; then exit $rc; fi
  fi

  if [ -n "${storage_account_name}" ] && [ "${resource_group_name}" ]
  then
    echo "Acquiring account key..."  
    account_key=$(az storage account keys list --resource-group "${resource_group_name}" --account-name "${storage_account_name}" --query '[0].value' -o tsv)
    rc=$?; if [[ $rc != 0 ]]; then exit $rc; fi
  fi

  if [ -n "${storage_account_name}" ] && [ "${resource_group_name}" ]
  then
    echo "Creating blob container..."  
    az storage container create --name "${storage_container_name}" --account-name "${storage_account_name}" --account-key "${account_key}"
    rc=$?; if [[ $rc != 0 ]]; then exit $rc; fi
  fi

  echo
  read -rp "Resources created. Press any key to continue "
}

generate_tf_code() {
echo
echo "# Generated Terraform Code. Copy the lines below in your main.tf file."
cat <<EOF
terraform {
  backend "azurerm" {
    resource_group_name   = "${resource_group_name}"
    storage_account_name  = "${storage_account_name}"
    container_name        = "${storage_container_name}"
    key                   = "terraform.tfstate"
  }
}

# Configure the Azure provider
provider "azurerm" { 
  # The "feature" block is required for AzureRM provider 2.x. 
  # If you are using version 1.x, the "features" block is not allowed.
  version = "~>2.0"
  features {}
}
EOF
}

# Main Script Execution
if ! command -v az &> /dev/null
then
  echo "Error: Azure CLI not found."
  echo "Aborting script execution."
  exit 1
fi

azcliversion="$(az --version | grep '^azure-cli'  | awk  '{print $2}' | awk -F. '{print $1}')"

if [ "$azcliversion" -ne "2" ]
  then
  echo "Error: Invalid Azure CLI version."
  echo "Aborting script execution."
  exit 1
fi
clear
horizontal_line='=================================================================='
echo -e "\n$horizontal_line"
echo "            Terraform Blob Storage Provisioner"
echo "$horizontal_line"
echo "1) Provision new storage account in a new resource group"
echo "2) Provision new storage account in an existing resource group"
echo "3) Provision new storage container in an existing storage account"
echo "4) Exit Terraform Blob Storage Provisioner"
echo "$horizontal_line"
echo
echo "For naming Azure storage resources check out"
echo "https://docs.microsoft.com/en-us/azure/azure-resource-manager/management/resource-name-rules#microsoftstorage"
echo
read -rp "Enter your selection: " choice
case "${choice}" in
  1)
    clear
    azure_location_name
    resource_group_name
    storage_account_name
    storage_storage_container_name
    verify_input
    generate_tf_code
    exit 0
    ;;
  2)
    clear
    resource_group_name
    storage_account_name
    storage_storage_container_name
    verify_input
    generate_tf_code
    exit 0
    ;;
  3)
    clear
    resource_group_name
    storage_account_name
    storage_storage_container_name
    verify_input
    generate_tf_code
    exit 0
    ;;
  4)
    clear
    echo "Aborting script execution."
    echo
    exit 0
    ;;
  *)
    echo "Invalid selection. Aborting script execution."
    echo "Aborting script execution."
    exit 1
    ;;
esac 