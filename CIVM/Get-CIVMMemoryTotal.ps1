# Get total Memory used in all VMs within Org VDC
$VDCName = 'VDC01'
$VDC = Get-OrgVdc -Name $VDCName
$VMs = $VDC | Get-CIVM
$VMs | Select-Object -ExpandProperty MemoryGB | Measure-Object -Sum | Select-Object -ExpandProperty Sum
