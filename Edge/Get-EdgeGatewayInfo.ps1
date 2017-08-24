# Pete Rossi script
$ExternalNetworks = Get-ExternalNetwork
$EdgeGateways = Search-Cloud -QueryType EdgeGateway
$VDCS = Get-OrgVDC *

$EdgeFinal = @()
$I = 1
$ECount = $EdgeGateways.count
ForEach ($EG in $EdgeGateways) {
    $P = ($I / $ECount) * 100
    $I += 1
    Write-Progress -Id 0 -Status "Processing" -Activity "$($EG.Name)" -PercentComplete $P
    Write-Host "Looking for VDC - $($EG.PropertyList.Vdc)"
    $VDC = $VDCS | Where-Object {$_.id -eq $EG.PropertyList.Vdc} | Select-Object -First 1

    $EGC = $EG | Get-CIView
    $Uplinks = $EGC.Configuration.GatewayInterfaces.GatewayInterface | Where-Object {$_.interfacetype -eq "uplink"}
    $UplinkCount = ($Uplinks | Measure-Object).count
    $UCount = 1

    if ($UplinkCount -eq 0) {
        Write-Host "No Uplinks Found For $($EG.Name)"
        $Holder = "" | Select-Object Org, VDCName, VDCID, EdgeGatewayName, EdgeGatewayID, NumberofExternalNetworks, NumberofOrgNetworks, UplinkCount, UplinkName, UplinkID, UplinkGateway, UplinkSubnet, UplinkVLANID, UplinkFirstIP, UplinkLastIP
        $Holder.Org = $VDC.Org.name
        $Holder.VDCName = $VDC.name
        $Holder.VDCID = $VDC.id
        $Holder.EdgeGatewayName = $EG.Name
        $Holder.EdgeGatewayID = $EG.id
        $Holder.NumberofExternalNetworks = $EG.NumberOfExtNetworks
        $Holder.NumberofOrgNetworks = $EG.NumberOfOrgNetworks
        $Holder.UplinkCount = $UplinkCount
        $EdgeFinal += $Holder
    }
    Else {
        Write-Host "Processing $UplinkCount for $($EG.Name)"
        ForEach ($Uplink in $Uplinks) {

            $OrgName = $VDC.org.name
            Write-Host "Looking for ORG $($OrgName)"
            $OSplit = $OrgName.Split("-")

            $CompanyData = Get-CompanyInfo -OrgName ($OrgName)

            $ThisRefSplit = $Uplink.Network.href.split("/")
            $ThisRef = $ThisRefSplit[$ThisRefSplit.count - 1]

            $TheEx = $ExternalNetworks | Where-Object {$_.id -like "*:$($ThisRef)*"}
            $Scopes = $TheEx.ExtensionData.Configuration.IpScopes.ipscope
            $ScopeCount = ($Scopes | Measure-Object).count

            $SubID = 0
            ForEach ($Scope in $Scopes) {
                $RangeCount = ($Scope.IpRanges.iprange | Measure-Object).count
                $RCount = 0
                Write-Host " - Processing Scope - $($Scope.Gateway)"
                ForEach ($Range in $Scope.IpRanges.iprange) {
                    $Holder = "" | Select-Object Org, CompanyID, AccountID, ServiceID, CompanyName, AccountName, ServiceName, VDCName, VDCID, EdgeGatewayName, EdgeGatewayID, NumberofExternalNetworks, NumberofOrgNetworks, NumberOfSubnets, UplinkCount, UplinkName, UplinkID, UplinkGateway, UplinkSubnet, UplinkVLANID, UplinkSubnetCount, UplinkSubnetID, UplinkRangeCount, UplinkRangeID, UplinkFirstIP, UplinkLastIP, TotalIPCount, UsedIPCount, UsedIPPercentage, FreeIPCount
                    Write-Host "   - Processing Range - $($Range.startaddress)"
                    $Holder.NumberOfSubnets = $ScopeCount

                    if ($CompanyData -ne $null) {
                        $Holder.CompanyName = $CompanyData.company_name
                        $Holder.AccountName = $CompanyData.account_name
                        $Holder.ServiceName = $CompanyData.service_name
                        $Holder.CompanyID = $OSplit[0]
                        $Holder.AccountID = $OSplit[1]
                        $Holder.ServiceID = $OSplit[2]
                    }
                    Else {
                        $Holder.CompanyName = "UNKNOWN"
                        $Holder.AccountName = "UNKNOWN"
                        $Holder.ServiceName = "UNKNOWN"
                        $Holder.CompanyID = $OSplit[0]
                        $Holder.AccountID = $OSplit[1]
                        $Holder.ServiceID = $OSplit[2]
                    }

                    $Holder.Org = $OrgName
                    $Holder.VDCName = $VDC.name
                    $Holder.VDCID = $VDC.id
                    $Holder.EdgeGatewayName = $EG.Name
                    $Holder.EdgeGatewayID = $EG.id
                    $Holder.NumberofExternalNetworks = $EG.NumberOfExtNetworks
                    $Holder.NumberofOrgNetworks = $EG.NumberOfOrgNetworks

                    $Holder.UplinkCount = $UplinkCount
                    $Holder.UplinkName = $TheEx.Name
                    $Holder.UplinkID = $TheEx.id
                    $Holder.UplinkGateway = $Scope.Gateway
                    $Holder.UplinkSubnet = $Scope.NetMask
                    $Holder.UplinkVLANID = $TheEx.vlanid
                    $Holder.UplinkFirstIP = $Range.startaddress
                    $Holder.UplinkLastIP = $Range.endaddress
                    $Holder.UplinkRangeCount = $RangeCount
                    $Holder.UplinkRangeID = $RCount
                    $Holder.UplinkSubnetCount = $ScopeCount
                    $Holder.UplinkSubnetID = $SubID
                    $RCount += 1

                    $NetworkSummary = Get-NetworkSummary -Ipaddress ($Scope.gateway) -subnetmask ($Scope.netmask)

                    $Holder.TotalIPCount = $NetworkSummary.NumberOfHosts - 1
                    $Holder.UsedIPCount = ($scope.AllocatedIpAddresses.IpAddress | Measure-Object).count
                    $Holder.UsedIPPercentage = [Math]::Round((($Holder.UsedIPCount / $Holder.TotalIPCount) * 100), 2)
                    $Holder.FreeIPCount = $Holder.TotalIPCount - $Holder.UsedIPCount

                    $EdgeFinal += $Holder
                }
                $SubID += 1
            }
        }
    }

}

$VCloudEdgeGatewaysPath = "$($ENV:Temp)\vCloudEdgeGatewayInfo-$((Get-Date).ToString('dd-MM-yyyy')).csv"
$EdgeFinal | Export-csv $VCloudEdgeGatewaysPath -NoTypeInformation
