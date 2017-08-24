# Get-CIVMTools_Customer.ps1
# Created: 2017-03-29
# Author: Adam Rush
#
# Gets VMware Tools version for VMs in specified Orgs
# VMware Tools Versions:
#  2147483647 = Guest Managed
#  8389 = VMware Tools version, standard installation method
#  "" = VMware Tools not installed, or cannot determine as VM powered off

# Variables - PLEASE MODIFY
$UserID = '1234.567.123456'
$OrgID = '111-222-3-abcdef'
$vCloudFQDN = 'vCloudServer01'
$PortalPassword = 'CHANGEME'

# Set Output Path
$Timestamp = (Get-Date -Format ("yyyy-MM-dd_HH-mm-ss"))
$OutputFolder = "$env:TEMP\vCloud-VMTools"
$OutputCSV = "vCloud-VMTools-Orgs_$(($OrgID -join "_").Replace('*',''))_$($Timestamp).csv"
$OutputPath = Join-Path -Path $OutputFolder -ChildPath $OutputCSV

# Create save path if it does not exist
$null = New-Item -Path $OutputFolder -ItemType Directory -Force

Write-Host "Connecting to $($vCloudFQDN)..." -ForegroundColor Yellow
Connect-CIServer -Server $vCloudFQDN -Org $OrgID -User $UserID -Password $PortalPassword

Write-Host "Finding all VMs in Org: $($OrgID)..." -ForegroundColor Cyan
$CIVMs = Get-CIVM

Write-Host "Found $($CIVMs.count) VMs..." -ForegroundColor Cyan

if ($CIVMs.Count -gt 0) {
    Write-Host "Preparing report..." -ForegroundColor Cyan
    $Report = $CIVMs | Select-Object Org, OrgVdc, VApp, Name, Status, @{n='VMTools'; e={$_.ExtensionData.GetRuntimeInfoSection().VMWareTools.version}}

    Write-Host "Exporting report to [ $($OutputPath) ]" -ForegroundColor Cyan
    $Report | Export-Csv -Path $OutputPath -NoTypeInformation -UseCulture
}

Write-Host "Disconnecting from $($vCloudFQDN)..." -ForegroundColor Yellow
Disconnect-CIServer -Server $vCloudFQDN -Confirm:$false