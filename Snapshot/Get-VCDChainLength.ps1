# Get vCloud VM chain length - shows linked-clones and snapshots in use
get-org lab | get-civm |
    Where-Object { $($_.ExtensionData.VCloudExtension.any.VirtualDisksMaxChainLength -as [int]) -gt 1 } |
    Select-Object name, vapp, org,
        @{N = 'Owner id'; E = {$_.vapp.owner}},
        @{N = 'Owner Full Name'; E = {$_.vapp.owner.fullname}},
        @{N = 'Chain Length'; E = {$_.ExtensionData.VCloudExtension.any.VirtualDisksMaxChainLength} } |
    Format-Table -AutoSize
