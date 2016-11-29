# Migrate an ARM resource group with virtual machines to Azure Managed Disks service using a destructive remove-recreate approach.

Built by: [colincole](https://github.com/colincole)

The EnableManagedDisks.ps1 PowerShell script allows someone to migrate an entire resource group and all contained resources to use the Azure Managed Disks service. The script will export the resource group to a template, modify the resource group's virtual machines and availability sets to use Managed Disks, remove the VM's and availability sets, then redeploy the incremental changes in the modified template. The Managed Disks service will import each disk on redeploy. No data will be lost but there will be some downtime to remove and recreate each VM.

