# Author: Adam Rush
# Created on: 2017-06-06

# Vars
$vCloudName = 'vCloudServer01'
$OrgName = '11-22-33-abcdef'
$VMName = 'MyVMName'
$MAC0 = '00:50:56:01:02:03'
$MAC1 = '00:50:56:01:02:04'

# Connect to vCloud
Connect-CIServer $vCloudName

# Get vCloud VM
$CIVM = Get-CIVM -Name $VMName -Org $OrgName

# Check current settings for first and second NICs
$CIVM.ExtensionData.Section[2].NetworkConnection[0].MACAddress
$CIVM.ExtensionData.Section[2].NetworkConnection[1].MACAddress

# Set new MAC Addresses for first and second NICs
$CIVM.ExtensionData.Section[2].NetworkConnection[0].MACAddress = $MAC0
$CIVM.ExtensionData.Section[2].NetworkConnection[1].MACAddress = $MAC1

# Update vCloud VM
$CIVM.ExtensionData.Section[2].UpdateServerData()

# Disconnect from vCloud
Disconnect-CIServer $vCloudName -Confirm:$false
