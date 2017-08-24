# Get Edge info from unparsed text report
<#
Connect-CIServer -Server 'vCloudServer01'
#>
# Vars
$ExportPath = "$($env:TEMP)\Edges-Orgs-VDCs_$((Get-Date -Format 'dd-MM-yyyy_HH-mm')).csv"

# Get Org and OrgVDC information from Edge names
Write-Host -ForegroundColor Yellow "Fetching Orgs..."
$Orgs = Search-Cloud -QueryType Organization
Write-Host -ForegroundColor Yellow "$($Orgs.count) Orgs found."

Write-Host -ForegroundColor Yellow "Fetching Org VDCs..."
$OrgVDCs = Search-Cloud -QueryType AdminOrgVdc
Write-Host -ForegroundColor Yellow "$($OrgVDCs.count) Org VDCs found."

$EdgesUnparsed = Get-Content -Path 'EdgeNames.txt'

# Just get Edge names
$EdgeNamesParsed = $EdgesUnparsed | Foreach-Object { $_.Split(' ')[-1] }

# Get unique Edge names
$EdgeNames = $EdgeNamesParsed | Select-Object -Unique | Sort-Object

# Get Edge objects
$Edges = $EdgeNames | Foreach-Object { Search-Cloud -QueryType EdgeGateway -Name "$($_.Trim())*" -ErrorAction SilentlyContinue }

$Report = foreach ($Edge in $Edges) {
    $OrgVDC = $OrgVDCs | Where-Object { $_.Id -eq $Edge.Vdc }
    [PSCustomObject] @{
        Org = $OrgVDC.OrgName
        VDC = $OrgVDC.Name
        Name = $Edge.Name
    }
}

$ReportUnique = $Report | Select-Object * -Unique
$ReportUnique | Export-Csv -Path $ExportPath -NoTypeInformation -UseCulture
Write-Host "Report exported to [$ExportPath]" -ForegroundColor Yellow
