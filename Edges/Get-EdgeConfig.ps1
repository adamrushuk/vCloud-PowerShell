
<#
.SYNOPSIS
Saves vCloud Edge configuration XML to file
	
.DESCRIPTION
Saves the full vCloud Edge configuration XML to file, and optionally prepares a separate XML file with VPN and/or Static Routes XML configuration pre-filled, ready to manually modify and upload later
	
.EXAMPLE
PS C:\> Connect-CIServer api.vcd.portal.skyscapecloud.com
PS C:\> .\Get-EdgeConfig.ps1 -Name nft000xxi3

.EXAMPLE
PS C:\> Connect-CIServer vcloud
PS C:\> .\Get-EdgeConfig.ps1 -Name "nft001a4i2 -1" -PrepareXML
	
.NOTES
Author: Adam Rush
Created: 2016-11-25
#>
	
Param (

[parameter(Mandatory=$true)]
[ValidateNotNullOrEmpty()]
[String]$Name,

[parameter(Mandatory=$false)]
[Switch]$PrepareXML
)    	
	
# Variables
$timestamp = (Get-Date -Format ("yyyy-MM-dd_HH-mm"))
$SavePath = "$HOME\Desktop\EdgeXML\$($Name)"
$EdgeXMLPath = "$SavePath\$($Name)_BACKUP_$($timestamp).xml"
$NewEdgeXMLPath = "$SavePath\$($Name)_VPN.xml"
    
# Create save path if it does not exist
if(!(Test-Path -Path $SavePath)){
	$TempObj = New-Item -ItemType Directory -Force -Path $SavePath
}

# Check for vcloud connection
if (-not $global:DefaultCIServers) {
    Write-Warning "Please connect to vcloud before using this function, eg. Connect-CIServer vcloud"
    Exit
}

# Find Edge
try {
	$EdgeView = Search-Cloud -QueryType EdgeGateway -Name $Name -ErrorAction Stop | Get-CIView
} catch {
    Write-Warning "Edge Gateway with name $Name not found, exiting..."
    Exit
}

# Test for null object
if ($EdgeView -eq $null) {
      Write-Warning "Edge Gateway result is NULL, exiting..."
      Exit    
}

# Test for 1 returned object
if ($EdgeView.Count -gt 1) {
      Write-Warning "More than 1 Edge Gateway found, exiting..."
      Exit    
}

# Set headers
$Headers = @{
    "x-vcloud-authorization"=$EdgeView.Client.SessionKey
    "Accept"=$EdgeView.Type + ";version=5.1"
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
if ($PSBoundParameters.ContainsKey("PrepareXML")){

	# Create new XML object
	[xml]$newXML = New-Object system.Xml.XmlDocument
	$newXML.LoadXml('<?xml version="1.0" encoding="UTF-8"?><EdgeGatewayServiceConfiguration xmlns="http://www.vmware.com/vcloud/v1.5"></EdgeGatewayServiceConfiguration>')
    
	# Import and save new VPN XML if current config exists
    if ($EGWConfXML.EdgeGateway.Configuration.EdgeGatewayServiceConfiguration.GatewayIpsecVpnService.Tunnel) {
        Write-Host -ForegroundColor yellow "VPN configuration found..."

	    $vpnNode = $newXML.ImportNode($EGWConfXML.EdgeGateway.Configuration.EdgeGatewayServiceConfiguration.GatewayIpsecVpnService,$true)
	    $TempObj = $newXML.EdgeGatewayServiceConfiguration.appendChild($vpnNode)
    }

	# Import and save new Static Routes XML if current config exists
    if ($EGWConfXML.EdgeGateway.Configuration.EdgeGatewayServiceConfiguration.StaticRoutingService.StaticRoute) {
        Write-Host -ForegroundColor yellow "Static Route configuration found..."

	    $staticRoutesNode = $newXML.ImportNode($EGWConfXML.EdgeGateway.Configuration.EdgeGatewayServiceConfiguration.StaticRoutingService,$true)
	    $TempObj = $newXML.EdgeGatewayServiceConfiguration.appendChild($staticRoutesNode)
    }

    # Save XML to filesystem
	$newXML.save($NewEdgeXMLPath)
    Write-Host -ForegroundColor yellow "New XML prepared and saved to $SavePath"
}

