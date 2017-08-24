$Edges = Import-Csv -Path 'Edges.csv'
$Edges | ForEach-Object { $_ | Add-Member –MemberType NoteProperty –Name Org –Value (Get-Org -Id "urn:vcloud:org:$($Edge.Tenant)").Name }
$Edges