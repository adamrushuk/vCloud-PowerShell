# Get vCloud snapshot details (this is very slow)
$Org = Get-Org -Name $OrgName
Write-Host "$($Org.Count) Orgs found."
Write-Host $Org

# Get-CIVM method
$StartTime = (Get-Date)
Write-Host "Started task at: $StartTime"

$CIVMs = $Org | Get-CIVM
Write-Host "$($CIVMs.Count) VMs found."

# Do task
Write-Host "Getting snapshot info."
$ChainLengthReport = $CIVMs | Select-Object  Org, OrgVdc, VApp, Name,
    @{N = 'SnapshotCreated'; E = {$_.ExtensionData.GetSnapshotSection().snapshot.Created}}

$ChainLengthReport | Where-Object 'SnapshotCreated' | Sort-Object Org, OrgVdc, VApp, Name, SnapshotCreated | Format-Table -AutoSize

$FinishTime = (Get-Date)
$Duration = New-TimeSpan -Start $StartTime -End $FinishTime
Write-Host "Snapshot info for $($CIVMs.Count) VMs found in: $($Duration.Minutes)m$($Duration.Seconds)s"
