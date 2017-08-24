# List all Edge subnets across multiple Orgs
<#
Connect-CIServer -Server vCloudServer01
#>
$OrgName = '11-22-*'
$Orgs = Search-Cloud -QueryType Organization -Name $OrgName

$Report = @()

foreach ($Org in $Orgs) {

    $OrgVDCs = Search-Cloud -QueryType AdminOrgVdc -Filter "Org==$($Org.Id)"

    foreach ($OrgVDC in $OrgVDCs) {

        $Edges = Search-Cloud -QueryType EdgeGateway -Filter "Vdc==$($OrgVDC.Id)"

        foreach ($Edge in $Edges) {

            $EdgeView = $Edge | Get-CIView
            $GatewayInterfaces = $EdgeView.Configuration.GatewayInterfaces.GatewayInterface |
                ForEach-Object {$_.SubnetParticipation} | Where-Object {$_.IpRanges -ne $null}

            foreach ($GatewayInterface in $GatewayInterfaces) {

                $Row = $GatewayInterface | Select-Object @{N = 'Org'; E = {$Org.Name}},
                    @{N = 'OrgVDC'; E = {$OrgVDC.Name}},
                    @{N = 'EdgeName'; E = {$Edge.Name}},
                    @{N = 'IpAddress'; E = {$_.IpAddress}},
                    @{N = 'Gateway'; E = {$_.Gateway}}
                $Report += $Row

            }
        }
    }
}

$Report | Sort-Object EdgeName, IpAddress | Format-Table -AutoSize

$EdgeNames = $Report | Select-Object -ExpandProperty EdgeName -Unique | Sort-Object
