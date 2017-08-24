<#
.SYNOPSIS
    Retrieves the metadata from all Org VDCs.
.DESCRIPTION
    Retrieves the provider-site, provider-region, and provider-zone metadata from all Org VDCs in a given Org.
.EXAMPLE
    Get-CIMetadata_Controller.ps1 -Server vCloudServer01 -Org '11-22-33-abcdef'

    Retrieves metadata for a single Org.
.EXAMPLE
    Get-CIMetadata_Controller.ps1 -Server vCloudServer01 -Org '11-22*'

    Retrieves metadata for all Orgs starting with 11-22.
.NOTES
    Author: Adam Rush
    Created: 2017-03-14
#>

[CmdletBinding()]
param (

    [parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Server,

    [parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string[]]$Org
)

# Load function
function Get-CIMetaData {
    <#
    .SYNOPSIS
        Retrieves all Metadata Key/Value pairs.
    .DESCRIPTION
        Retrieves all custom Metadata Key/Value pairs on a specified vCloud object
    .PARAMETER  CIObject
        The object on which to retrieve the Metadata.
    .PARAMETER  Key
        The key to retrieve.
    .EXAMPLE
        Get-CIMetadata -CIObject (Get-Org Org1)
    .LINK
        http://kiwicloud.ninja/2016/02/working-with-vcloud-metadata-in-powercli-part-1
    #>
    param(
        [parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [PSObject[]]$CIObject,
        $Key
    )
    Process {
        Foreach ($Object in $CIObject) {
            If ($Key) {
                ($Object.ExtensionData.GetMetadata()).MetadataEntry | Where-Object {$_.Key -eq $key } | Select-Object @{N = "CIObject"; E = {$Object.Name}},
                @{N = "Type"; E = {$_.TypedValue.GetType().Name}},
                @{N = "Visibility"; E = { if ($_.Domain.Visibility) { $_.Domain.Visibility } else { "General" }}},
                Key -ExpandProperty TypedValue
            }
            Else {
                ($Object.ExtensionData.GetMetadata()).MetadataEntry | Select-Object @{N = "CIObject"; E = {$Object.Name}},
                @{N = "Type"; E = {$_.TypedValue.GetType().Name}},
                @{N = "Visibility"; E = { if ($_.Domain.Visibility) { $_.Domain.Visibility } else { "General" }}},
                Key -ExpandProperty TypedValue
            }
        }
    }
}

# Vars
$Report = @()

# Connect vCloud
Write-Host "Connecting to $vCloudURL..." -ForegroundColor Yellow
$null = Connect-CIServer $vCloudURL -ErrorAction Stop

# Get Orgs
Write-Host "Finding all Orgs matching $Org..." -ForegroundColor Cyan
$Orgs = Get-Org -Name $Org
if ($Orgs.Count -lt 1) {
    throw "No Orgs were found using $Org"
}
Write-Host "Orgs found: $($Orgs.Count)" -ForegroundColor Green

# Progress bar vars
$Activity = "Processing all Orgs found..."
$TotalOrgs = $Orgs.Count
$Counter = 1
$StepText = ""
$StatusText = '"Org $($Counter.ToString().PadLeft($TotalOrgs.Count.ToString().Length)) of $($TotalOrgs): $StepText"'
$StatusBlock = [ScriptBlock]::Create($StatusText)

Write-Host "`nFinding all VDCs in each Org..." -ForegroundColor Cyan
foreach ($Org in $Orgs) {

    $StepText = "$($Org.Name)"

    $VDCs = $Org | Get-OrgVdc
    Write-Verbose "VDCs found: $($VDCs.Count)"

    $CounterVDC = 1

    foreach ($VDC in $VDCs) {

        $Task = "VDC $CounterVDC of $($VDCs.Count): $($VDC.Name)"
        Write-Progress -Id 1 -Activity $Activity -Status (&$StatusBlock) -CurrentOperation $Task -PercentComplete ($Counter / $TotalOrgs * 100)

        $Metadata = $VDCs | Get-CIMetadata
        #$Metadata | Select @{N='Org';E={$OrgName}}, CIObject, Key, Value

        $Groups = $Metadata | Group-Object -Property CIObject
        $Report += $Groups | Select-Object  @{N = 'Org'; E = {$Org.Name}},
            @{N = 'OrgVDC'; E = {$_.Name}},
            @{N = 'provider-site'; E = {$_.Group | Where-Object {$_.Key -eq 'provider-site'} | Select-Object $_.Value -ExpandProperty Value}},
            @{N = 'provider-region'; E = {$_.Group | Where-Object {$_.Key -eq 'provider-region'} | Select-Object $_.Value -ExpandProperty Value}},
            @{N = 'provider-zone'; E = {$_.Group | Where-Object {$_.Key -eq 'provider-zone'} | Select-Object $_.Value -ExpandProperty Value}}
        $CounterVDC++
    }

    $Counter++
}

# Display to screen and copy to clipboard
$Report | Format-Table -AutoSize
$Report | Format-Table -AutoSize | clip
Write-Host "`nResults were copied to the clipboard." -ForegroundColor Green

# Disconnect vCloud
Write-Host "Disconnecting from $vCloudURL..." -ForegroundColor Yellow
Disconnect-CIServer $vCloudURL -Confirm:$false
