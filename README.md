# azure-shell-scripts

Collection of scripts mostly using on Azure CLI


## terraform-blob-provisioner.sh

This script creates Azure blob storage to be used for storing terraform state. Before you run the script ensure you have an active Azure account with permission to create storage resources, and the know the following information:

* Azure region name (e.g. eastus, westus, westeurope, northeurope)
* Azure account name ([make sure you understand the Azure account name restrictions first](https://docs.microsoft.com/en-us/azure/azure-resource-manager/management/resource-name-rules#microsoftstorage) if you create a new storage account)
* Azure blob container name. Azure blob names are unique accross the Azure storage account. To ensure name uniquness the script allows you to append a timestamp based on Unix epoch in days.

Example data
```bash
Resource group name: 1-2f46bd10-playground-sandbox
Storage account name: playgroundsandboxstacct
Storage container: terraform-18631
```

**Note: The script does some minor input validation. Make sure you understand the naming restrictions before create any new storage resources.**