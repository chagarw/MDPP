# Script: Enable Managed Disks Service
# Purpose: Takes a deployed ARM resource group and destructively (delete/recreate) migrates the VM disks to the Managed Disks service.
#    The migration will happen by deleting the VM (but not the VHD files) and recreating the VMs so the disks are imported to Managed Disks service.
#    After running this script successfully, the disks underneath the VMs will be migrated to Managed Disks with everything else unchanged.
#
# Version 1.02   2016-11-29
#

Param
(
    [Parameter(Mandatory=$true)]
	[string]$ResourceGroupName,   # Resource Group containing VMs to move to Managed Disks
    [Parameter(Mandatory=$true)]
    [string]$SubscriptionID,       # subscription ID
    [Parameter(Mandatory=$false)]
    [switch]$AllowTemplateChanges = $false  # Set this flag to pause the script, prompt, and allow the user to manually update the template before final deployment. Use this to enable scenarios like upgrading from standard blob storage to Managed Disks premium storage -- for example. To upgrade, see README.md.
)

$global:ScriptStartTime = (Get-Date -Format hh-mm-ss.ff)

if((Test-Path "Output") -eq $false)
{
	md "Output" | Out-Null
}

function Write-Log
{
	param(
        [string]$logMessage,
	    [string]$color="White"
    )

    $timestamp = ('[' + (Get-Date -Format hh:mm:ss.ff) + '] ')
	$message = $timestamp + $logMessage
    Write-Host $message -ForeGroundColor $color
	$fileName = "Output\Log-" + $global:ScriptStartTime + ".log"
	Add-Content $fileName $message
}

try
{
    $fileName = $ResourceGroupName + ".json"
    $newFileName = "MD_" + $ResourceGroupName + ".json"

    Write-Log "-----------------------------------------------------------------------------------------"
    Write-Log "starting the Managed Disks migration for $ResourceGroupName resource group"
    Write-Log $fileName
    Write-Log $newFileNameon 

    Select-AzureRmSubscription -SubscriptionId $SubscriptionID

    Write-Log "Exporting resource group template" 
    Export-AzureRmResourceGroup -ResourceGroupName $ResourceGroupName -IncludeParameterDefaultValue -Force -ErrorAction Stop
    
    Write-Log "Walking through list of VMs in the RG to collect info"
    $vms = Get-AzureRmVM -ResourceGroupName $ResourceGroupName -ErrorAction Stop
    if ($vms.Count -eq 0) 
    { 
        Write-Log "No VMs were found in the RG to move to Managed Disks. Exiting script."
        exit
    }

    $vmsList = ""  # create a list of VM names to be moved to MD and provide the os type for each VM.  example: vw000598|Linux,vw000333|Windows
    foreach ($vm in $vms)
    {
        if ($vmsList -eq "")
        {
            $vmsList = $vmsList + $vm.Name + '|' + $vm.StorageProfile.OsDisk.OsType
        }
        else
        {
            $vmsList = $vmsList + ',' + $vm.Name + '|' + $vm.StorageProfile.OsDisk.OsType
        }
    }

    Start-Sleep 5

    Write-Log "Calling out to the EnableMD.exe .NET app to modify the exported RG template and enable Managed Disks." 
    Write-Log "EnableMD.exe $fileName $vmsList"
   .\EnableMD.exe $fileName $vmsList
    
    Write-Log "Created a modified template: $newFileName." 

    if ($AllowTemplateChanges)
    {
        Write-Log "Look for a Message Box prompt that may be behind other windows. Pausing script to allow a user to modify the template file $newFileName before deployment. Modify and save this file if further custom changes are desired. For example, use this feature to upgrade to Managed Disks Premium Storage (from standard unmanaged blob storage). To upgrade from standard unmanaged blob storage to managed premium storage, see further instructions in the README.md." -color Yellow
        $msg = "Pausing script to allow a user to modify the template file $newFileName before deployment. Modify and save this file if further custom changes are desired. For example, use this feature to upgrade to Managed Disks Premium Storage (from standard unmanaged blob storage). To upgrade from standard unmanaged blob storage to managed premium storage, see further instructions in the README.md."
        $out = [System.Windows.Forms.MessageBox]::Show($msg, "Yes-Continue with Deployment, or No-ExitScript and cancel changes?" , 4) 
        if ($out -eq "No" ) 
        {
            Exit 
        }
    }
     
    Write-Log "Deleting the VMs in the RG. This will take some time..." 
    
    foreach ($vm in $vms)
    {
        Write-Log "Removing VM: $($vm.Name)"
        Remove-AzureRmVM -Name $vm.Name $vm.ResourceGroupName -Force -ErrorAction Stop
        Write-Log "success: Removing VM: $($vm.Name)" -color Green
    }

    Write-Log "Check for availability sets"
    $as = Get-AzureRmAvailabilitySet -ResourceGroupName $ResourceGroupName
    if ($as -ne $null) 
    { 
        Write-Log "Removing availability set: $($as[0].Name). It will be recreated as a managed AS."
        Remove-AzureRmAvailabilitySet -ResourceGroupName $ResourceGroupName -Name $as[0].Name -Force -ErrorAction Stop
        Write-Log "Success removing the AS" -color Green
    }

    Start-Sleep 5

    Write-Log "Deploying modified resource group template: $newFileName to recreate the deleted VMs." 
    New-AzureRmResourceGroupDeployment -ResourceGroupName $ResourceGroupName -TemplateFile $newFileName -Mode Incremental -ErrorAction Stop

    Write-Log "Deployment Success. Script completed." -color "Green"
}
catch
{
    Write-Log "Error moving the resource group $ResourceGroupName to Managed Disk. Following exception was caught $($_.Exception.Message)" -color "Red"
    Write-Log "Manually resolve the error by tweaking the $newFileName template, then do an incremental redeploy with New-AzureRmResourceGroupDeployment"
}