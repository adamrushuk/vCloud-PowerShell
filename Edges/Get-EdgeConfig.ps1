<#
    .SYNOPSIS
    Saves vCloud Edge configuration XML to file

    .DESCRIPTION
    Saves the full vCloud Edge configuration XML to file, and optionally prepares a separate XML file with VPN and/or Static Routes XML configuration pre-filled, ready to manually modify and upload later

    .EXAMPLE
    Connect-CIServer api.vcd.portal.skyscapecloud.com
    .\Get-EdgeConfig.ps1 -Name nft000xxi2

    Exports the Edge configuration.

    .EXAMPLE
    Connect-CIServer api.vcd.portal.skyscapecloud.com
    .\Get-EdgeConfig.ps1 -Name "nft00001i2" -PrepareXML

    Exports the Edge configuration and also prepares XML for VPN and Static Routes.

    .NOTES
    Author: Adam Rush
    Created: 2016-11-25
#>
[CmdletBinding()]
Param (

    [parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [String]$Name,

    [parameter(Mandatory = $false)]
    [Switch]$PrepareXML

)

# Variables
$timestamp = (Get-Date -Format ("yyyy-MM-dd_HH-mm"))
$SavePath = "$HOME\Desktop\EdgeXML\$($Name)"
$EdgeXMLPath = "$SavePath\$($Name)_BACKUP_$($timestamp).xml"
$NewEdgeXMLPath = "$SavePath\$($Name)_VPN.xml"

# Create save path if it does not exist
if (!(Test-Path -Path $SavePath)) {
    $null = New-Item -ItemType Directory -Force -Path $SavePath
}

# Check for vcloud connection
if (-not $global:DefaultCIServers) {
    throw "Please connect to vcloud before using this function, eg. Connect-CIServer vcloud"
}

# Find Edge
try {
    $EdgeView = Search-Cloud -QueryType EdgeGateway -Name $Name -ErrorAction Stop | Get-CIView
} catch {
    throw "Edge Gateway with name $Name not found, exiting..."
}

# Test for null object
if ($EdgeView -eq $null) {
    throw "Edge Gateway result is NULL, exiting..."

}

# Test for 1 returned object
if ($EdgeView.Count -gt 1) {
    throw "More than 1 Edge Gateway found, exiting..."

}

# Set headers
$Headers = @{
    "x-vcloud-authorization" = $EdgeView.Client.SessionKey
    "Accept" = $EdgeView.Type + ";version=5.1"
}

# Get Edge Configuration in XML format
$Uri = $EdgeView.href
[XML]$EGWConfXML = Invoke-RestMethod -URI $Uri -Method GET -Headers $Headers

# Show Edge HREF
Write-Host -ForegroundColor yellow "Edge HREF for API REST Client usage is: $($EdgeView.href)"

# Export XML
$EGWConfXML.save($EdgeXMLPath)
Write-Host -ForegroundColor yellow "XML Config saved to $SavePath"

# Prepare and save VPN XML file if requested
if ($PSBoundParameters.ContainsKey("PrepareXML")) {

    # Create new XML object
    [xml]$newXML = New-Object system.Xml.XmlDocument
    $newXML.LoadXml('<?xml version="1.0" encoding="UTF-8"?><EdgeGatewayServiceConfiguration xmlns="http://www.vmware.com/vcloud/v1.5"></EdgeGatewayServiceConfiguration>')

    # Import and save new VPN XML if current config exists
    if ($EGWConfXML.EdgeGateway.Configuration.EdgeGatewayServiceConfiguration.GatewayIpsecVpnService.Tunnel) {
        Write-Host -ForegroundColor yellow "VPN configuration found..."

        $vpnNode = $newXML.ImportNode($EGWConfXML.EdgeGateway.Configuration.EdgeGatewayServiceConfiguration.GatewayIpsecVpnService, $true)
        $null = $newXML.EdgeGatewayServiceConfiguration.appendChild($vpnNode)
    }

    # Import and save new Static Routes XML if current config exists
    if ($EGWConfXML.EdgeGateway.Configuration.EdgeGatewayServiceConfiguration.StaticRoutingService.StaticRoute) {
        Write-Host -ForegroundColor yellow "Static Route configuration found..."

        $staticRoutesNode = $newXML.ImportNode($EGWConfXML.EdgeGateway.Configuration.EdgeGatewayServiceConfiguration.StaticRoutingService, $true)
        $null = $newXML.EdgeGatewayServiceConfiguration.appendChild($staticRoutesNode)
    }

    # Save XML to filesystem
    $newXML.save($NewEdgeXMLPath)
    Write-Host -ForegroundColor yellow "New XML prepared and saved to $SavePath"
}