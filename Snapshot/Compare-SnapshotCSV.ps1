function Compare-SnapshotCSV {
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

    Param
    (
        [Parameter(Mandatory=$true)]
        $ReferenceObject,

        [Parameter(Mandatory=$true)]
        $DifferenceObject
    )

    # Create new VMId property for comparison
    $ReferenceObject |
        ForEach-Object { $moref = $_.moref; $_ |
            Add-Member -MemberType noteproperty -Name VMId -Value "VirtualMachine-$moref"}

    # Compare using concatenated moref (vCloud VM Id)
    Compare-Object -ReferenceObject $ReferenceObject -DifferenceObject $DifferenceObject -Property VMId -PassThru

}
