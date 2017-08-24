$vCloudURL = 'vCloudServer01'
$OrgName = '11-22-33-abcdef'
Connect-CIServer -Server $vCloudURL -Org $OrgName

<#
TimeStamp doesn't work (even though we could filter for tasks)??
NOTE: there is also a bug where you cannot use a + sign eg. '2017-08-23T00:00:00.0000000+01:00'
This is due to it not being escaped properly for use as a URI
#>
$DateTimeString = '2017-08-23T00:00:00.0000000-00:00'
$EscapedDateTimeString = [uri]::EscapeUriString($DateTimeString)
$FilteredEvents = Search-Cloud -QueryType Event -Filter "TimeStamp=ge=$EscapedDateTimeString"
$FilteredEvents.Count
