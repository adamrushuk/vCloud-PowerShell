Import-Module VMware.VimAutomation.Cloud -Verbose

Connect-CIServer -Server 'vcloud'
$CIVMs = Get-CIVM
$CIVMs | Select-Object Name, @{n='DateCreated';e={$_.ExtensionData.DateCreated}}
