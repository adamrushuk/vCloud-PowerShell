<#
.SYNOPSIS
Uploads vCloud Edge XML configuration to vCloud
	
.DESCRIPTION
Uploads vCloud Edge VPN and/or Static Routes XML configuration to vCloud via the API

.EXAMPLE
PS C:\> Connect-CIServer api.vcd.portal.skyscapecloud.com
PS C:\> .\Set-EdgeConfig.ps1 -Name "nft000xxi2-1" -Path "C:\Path\To\EdgeXML\nft000xxi2-1\nft000xxi2-1_VPN_SR.xml"

.NOTES
Author: Adam Rush
Created: 2016-11-25
#>
	
Param (

[parameter(Mandatory=$true)]
[ValidateNotNullOrEmpty()]
[String]$Name,

[parameter(Mandatory=$true)]
[ValidateNotNullOrEmpty()]
[String]$Path
)    	

# Test XML path exists
if(!(Test-Path -Path $Path)){
    Write-Warning "$Path not found"
    Exit
}

if (-not $global:DefaultCIServers) {
    Write-Warning "Please connect to vcloud before using this function, eg. Connect-CIServer vcloud"
    Exit
}

#Search EdgeGW
try {
  $EdgeView = Search-Cloud -QueryType EdgeGateway -Name $Name | Get-CIView
} catch {
      Write-Warning "Edge Gateway with name $EdgeView not found"
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

# Load XML
[XML]$Body = Get-Content -Path $Path

# Upload new VPN XML Edge config 
$Uri = ($EdgeView.Href + "/action/configureServices")

# Set headers
$Headers = @{
    "x-vcloud-authorization"=$EdgeView.Client.SessionKey
    "Accept"="application/*+xml;version=5.1"
    "Content-Type"="application/vnd.vmware.admin.edgeGatewayServiceConfiguration+xml"
}

# Upload XML
Write-Host -ForegroundColor yellow "Updating Edge Gateway $Name" -NoNewline
$Response = Invoke-RestMethod -URI $Uri -Method POST -Headers $Headers -Body $Body 

# Get Task progress
$TaskHref = $Response.Task.href 
Do {
    $Task = Invoke-RestMethod -URI $TaskHref -Method GET -Headers $Headers
    Write-Host -ForegroundColor yellow "." -NoNewline
    Start-Sleep 2
} While ($Task.Task.status -eq "running")

Write-Host -ForegroundColor yellow "."
Write-Host -ForegroundColor green "Edge update complete"

