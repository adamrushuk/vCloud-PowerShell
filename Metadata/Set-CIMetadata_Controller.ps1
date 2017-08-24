# Author: Adam Rush
# Set vCloud VM License Metadata controller script

# Load main function
. 'CIMetadata.ps1'

# Vars
$OrgName = '11-22-33'
$vAppName = 'vApp1'
$VMName = 'VM1'

$LicenseType = 'SQL'
$LicenseVersion = '2014' # 2012, 2014
$LicenseEdition = 'STD' # STD, or ENT
$LicenseRequestID = 'REQ100123'

$Org = Get-Org -Name $OrgName
$CIVM = Get-CIVApp -Name $vAppName -Org $Org | Get-CIVM -Name $VMName

if (($CIVM).count -gt 1) { throw "More than 1 VM found for supplied name. Please enter more specific data."}

# Build Metadata value string
$LicensevCPUs = $CIVM.CpuCount
$MetadataValue = "$LicenseType,$LicenseVersion,$LicenseEdition,$LicensevCPUs,$LicenseRequestID"

# Add License Metadata
$CIVM | New-CIMetadata -Key 'License' -Value $MetadataValue -Visibility READONLY
