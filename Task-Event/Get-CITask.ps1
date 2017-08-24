$vCloudURL = 'vCloudServer01'
$OrgName = '11-22-33-abcdef'
Connect-CIServer -Server $vCloudURL -Org $OrgName

<#
This works as uses full DateTime format
NOTE: there is a bug where you cannot use a + sign eg. '2017-08-23T00:00:00.0000000+01:00'
This is due to it not being escaped properly for use as a URI
#>
$DateTimeString = '2017-08-23T00:00:00.0000000-00:00'
$EscapedDateTimeString = [uri]::EscapeUriString($DateTimeString)
$FilteredTasks = Search-Cloud -QueryType Task -Filter "startDate=ge=$EscapedDateTimeString"
$FilteredTasks.Count
$FilteredTasks | Sort-Object StartDate | Select-Object StartDate, EndDate, Name, Status

# Target by object name and type
$SCTasks | Where-Object { $_.ObjectName -match 'AR-Test-01' } | Sort-Object StartDate
$SCTasks | Where-Object { $_.ObjectName -match 'AR-Test-01' -and $_.ObjectType -eq 'vm' } | Sort-Object StartDate | Select-Object -Last 2
