# Get all Edge versions across multiple vCenters
# Vars
$CSVReportFolder = Join-Path -Path $env:USERPROFILE -ChildPath '\Desktop\Edges'
$StartTime = Get-Date
$Timestamp = (Get-Date -Format ("yyyyMMdd-HHmm"))
$Padding = " " * 2

$vCenterNames = @(
    'vCenterServer01'
    'vCenterServer02'
    'vCenterServer03'
)

# Check report path
$null = New-Item -Path $CSVReportFolder -ItemType directory -Force -ErrorAction Stop

Write-Host "[$StartTime] Script started." -ForegroundColor Yellow
Write-Host "[$(Get-Date)] Finding Edges in these vCenters: $($vCenterNames | Out-String)" -ForegroundColor Cyan

foreach ($vCenter in $vCenterNames) {

    # Connect to vCenter
    Write-Host "[$(Get-Date)] Logging in to $($vCenter)..." -ForegroundColor Yellow
    $null = Connect-VIServer $vCenter -ErrorAction Stop

    # Find Edges
    Write-Host "[$(Get-Date)] $Padding Finding all Edges in $($vCenter)..." -ForegroundColor Cyan
    $Edges = Get-View -ViewType virtualmachine -Property Name,Config -Filter @{'Config.VAppConfig.Product[0].Name'='vShield Edge'} |
        Select-Object Name, @{ n='Version';e={$_.config.vappconfig.product[0].version} }
    Write-Host "[$(Get-Date)] $Padding $($Edges.count) Edges found." -ForegroundColor Cyan

    # Save Edges
    $vCenterReportPath = Join-Path -Path $CSVReportFolder -ChildPath "$($vCenter)-Edges_$($Timestamp).csv"
    Write-Host "[$(Get-Date)] $Padding Exporting $($vCenter) Edges to: " -ForegroundColor Cyan -NoNewline
    Write-Host "[$($vCenterReportPath)]" -ForegroundColor Yellow
    $Edges | Export-Csv -Path $vCenterReportPath -NoTypeInformation -UseCulture

    # Disconnect from vCenter
    Write-Host "[$(Get-Date)] $Padding Logging out of $($vCenter)..." -ForegroundColor Cyan
    Disconnect-VIServer $vCenter -Confirm:$false

}

$FinishTime = (Get-Date)
$Duration = New-TimeSpan -Start $StartTime -End $FinishTime
Write-Host "[$(Get-Date)] Script complete. " -ForegroundColor Yellow -NoNewline
Write-Host "Script duration: $($Duration.Minutes)m$($Duration.Seconds)s" -ForegroundColor Yellow
