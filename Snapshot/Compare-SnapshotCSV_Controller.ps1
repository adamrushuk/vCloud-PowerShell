<#
.SYNOPSIS
    Finds snapshots that do not exist in the Database CSV.

.DESCRIPTION
    Finds snapshots that do not exist in the Database CSV export and exist in the vCenter CSV export.

.EXAMPLE
    Compare-SnapshotCSV -ReferenceObject $DatabaseCSV -DifferenceObject $vCenterCSV

.NOTES
    Author: Adam Rush
    Created: 2017-03-09
#>

[CmdletBinding()]
param (

    [parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$DatabaseCSVPath,

    [parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$vCenterCSVPath
)

# Load function
. 'Compare-SnapshotCSV.ps1'

# Vars
$Timestamp = (Get-Date -Format ("yyyy-MM-dd_HH-mm-ss"))
$CSVReportFolder = "$($env:TEMP)\Reports\Snapshots"
$CSVPath = "$CSVReportFolder\Snapshot-Comparison-Results-$($Timestamp).csv"

# Check report path
$null = New-Item -Path $CSVReportFolder -ItemType directory -Force -ErrorAction Stop

# Load CSVs
Write-Host "Loading snapshots" -ForegroundColor Yellow
$DatabaseCSV = Import-Csv -Path $DatabaseCSVPath -ErrorAction Stop
$vCenterCSV = Import-Csv -Path $vCenterCSVPath -ErrorAction Stop

Write-Host "Database CSV has $($DatabaseCSV.Count) snapshots" -ForegroundColor Cyan
Write-Host "vCenter CSV has $($vCenterCSV.Count) snapshots" -ForegroundColor Cyan

# Example values
Write-Verbose "Database CSV values"
$DatabaseCSV[0] | Format-List *
Write-Verbose "vCenter CSV values"
$vCenterCSV[0] | Format-List *

# Compare CSVs
$Results = Compare-SnapshotCSV -ReferenceObject $DatabaseCSV -DifferenceObject $vCenterCSV

# Export to CSV
Write-Host "Exporting results to [$CSVPath]..." -ForegroundColor Green
$Results | Select-Object vCenter, Created, Org, OrgName, OrgVDC, vApp, VM, VMId, PowerState, SizeGB, Name,
    Description, SideIndicator | Export-Csv -Path $CSVPath -NoTypeInformation -UseCulture
