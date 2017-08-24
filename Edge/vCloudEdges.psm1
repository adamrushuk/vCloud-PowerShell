# A module for vShield Edges
# Adam Rush
# Updated: 2017-02-09 20:08

## vCloud Director Functions ##
function Get-EdgeView {
    <#
    .SYNOPSIS
        Gets the Edge View.
    .DESCRIPTION
        Gets the Edge View using the Search-Cloud cmdlet.
    .PARAMETER Name
        Specify a single vShield Edge name. Use quotes if the name includes spaces.
    .EXAMPLE
        $EdgeView = Get-EdgeView -Name "Edge01"
    .NOTES
        Author: Adam Rush
        Created: 2016-12-08
    #>

    [CmdletBinding()]
    [OutputType('VMware.VimAutomation.Cloud.Views.Gateway')]
    param (

        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Name
    )

    # Check for vcloud connection (User property sometimes clears when intermittent issues, so worth checking)
    if (-not $global:DefaultCIServers[0].User) {
        throw "Please connect to vcloud before using this function, eg. Connect-CIServer vcloud"
    }

    # Find Edge
    try {
        $EdgeView = Search-Cloud -QueryType EdgeGateway -Name $Name | Get-CIView
    }
    catch [Exception] {
        throw "Edge Gateway with name $Name not found, exiting."
    }

    # Test for null object
    if ($EdgeView -eq $null) {
        throw "Edge Gateway result is NULL, exiting."
    }

    # Test for 1 returned object
    if ($EdgeView.Count -gt 1) {
        throw "More than 1 Edge Gateway found, exiting."
    }

    return $EdgeView
}

function Get-EdgeXML {
    <#
    .SYNOPSIS
        Gets the vCloud Edge configuration XML.
    .DESCRIPTION
        Gets the vCloud Edge configuration XML using the REST API.
    .PARAMETER EdgeView
        EdgeView object for SessionKey and Name properties.
    .EXAMPLE
        $EdgeXML = Get-EdgeXML $EdgeView
    .NOTES
        Author: Adam Rush
        Created: 2016-12-08
    #>

    [CmdletBinding()]
    [OutputType('System.Xml.XmlDocument')]
    param (

        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [VMware.VimAutomation.Cloud.Views.Gateway]$EdgeView
    )

    # Get Edge XML
    try {
        # Set headers
        $Headers = @{
            "x-vcloud-authorization" = $EdgeView.Client.SessionKey
            "Accept"                 = "application/*+xml;version=5.1"
        }

        # Get Edge Configuration in XML format
        $Uri = $EdgeView.href
        [XML]$EdgeXML = Invoke-RestMethod -URI $Uri -Method GET -Headers $Headers

    }
    catch [Exception] {
        throw "Could not get configuration XML for [$($EdgeView.Name)]."
    }

    return $EdgeXML
}

function Export-EdgeXML {
    <#
    .SYNOPSIS
        Exports vCloud Edge configuration XML to file.
    .DESCRIPTION
        Exports the full vCloud Edge configuration XML to file, and optionally prepares a separate XML file
        with VPN and/or Static Routes XML configuration pre-filled, ready to manually modify and upload later using Set-EdgeConfig.ps1
    .PARAMETER EdgeXML
        Provide an EdgeXML object.
    .PARAMETER Type
        Specifies the export type.
    .PARAMETER PrepareXML
        Optionally prepare a separate XML file with VPN and/or Static Routes XML configuration pre-filled.
    .EXAMPLE
        Export-EdgeXML $EdgeXML -Type FULL
    .EXAMPLE
        Export-EdgeXML $EdgeXML -Type FULL -PrepareXML
    .EXAMPLE
        Export-EdgeXML $EdgeXML -Type REPARTICIPATE
    .NOTES
        Author: Adam Rush
        Created: 2016-11-25
    #>

    [CmdletBinding()]
    param (

        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.Xml.XmlDocument]$EdgeXML,

        [parameter(Mandatory = $false)]
        [string]$Type,

        [parameter(Mandatory = $false)]
        [switch]$PrepareXML
    )

    # Variables
    $EdgeName = $EdgeXML.EdgeGateway.name # TODO: add ValidateScript to check this property specifically is not null
    $timestamp = (Get-Date -Format ("yyyy-MM-dd_HH-mm"))
    $SavePath = "$(Split-Path $script:MyInvocation.MyCommand.Path)\EdgeXML\$($EdgeName)" # this may work when calling from other script
    $EdgeXMLPath = "$SavePath\$($EdgeName)_$($Type)_$($timestamp).xml"
    $NewEdgeXMLPath = "$SavePath\$($EdgeName)_VPN_SR.xml"

    # Create save path if it does not exist
    if (!(Test-Path -Path $SavePath)) {
        $null = New-Item -ItemType Directory -Force -Path $SavePath
    }

    # Export XML
    $EdgeXML.save($EdgeXMLPath)
    Write-Verbose "XML Config saved to $SavePath"

    # Prepare and save VPN XML file if requested
    if ($PSBoundParameters.ContainsKey("PrepareXML")) {

        # Create new XML object
        [xml]$newXML = New-Object system.Xml.XmlDocument
        $newXML.LoadXml('<?xml version="1.0" encoding="UTF-8"?><EdgeGatewayServiceConfiguration xmlns="http://www.vmware.com/vcloud/v1.5"></EdgeGatewayServiceConfiguration>')

        # Import and save new VPN XML if current config exists
        if ($EdgeXML.EdgeGateway.Configuration.EdgeGatewayServiceConfiguration.GatewayIpsecVpnService.Tunnel) {
            Write-Verbose "VPN configuration found..."

            $vpnNode = $newXML.ImportNode($EdgeXML.EdgeGateway.Configuration.EdgeGatewayServiceConfiguration.GatewayIpsecVpnService, $true)
            $null = $newXML.EdgeGatewayServiceConfiguration.appendChild($vpnNode)
        }

        # Import and save new Static Routes XML if current config exists
        if ($EdgeXML.EdgeGateway.Configuration.EdgeGatewayServiceConfiguration.StaticRoutingService.StaticRoute) {
            Write-Verbose "Static Route configuration found..."

            $staticRoutesNode = $newXML.ImportNode($EdgeXML.EdgeGateway.Configuration.EdgeGatewayServiceConfiguration.StaticRoutingService, $true)
            $null = $newXML.EdgeGatewayServiceConfiguration.appendChild($staticRoutesNode)
        }

        # Save XML to filesystem
        $newXML.save($NewEdgeXMLPath)
        Write-Verbose "New XML prepared and saved to $SavePath"
    }

}

function Import-EdgeServicesXML {
    <#
    .SYNOPSIS
        Imports vCloud Edge Services XML configuration into vCloud
    .DESCRIPTION
        Imports vCloud Edge VPN and/or Static Routes XML configuration to vCloud via the API
    .EXAMPLE
        Connect-CIServer vcloud01
        Import-EdgeServicesXML -Name "Edge01" -Path "C:\Path\To\EdgeXML\Edge01\Edge01_VPN_SR.xml"
    .EXAMPLE
        Import-EdgeServicesXML -Name "Edge01" -XML $EdgeServicesXML
    .NOTES
        Author: Adam Rush
        Created: 2016-12-08
    #>

    [CmdletBinding(DefaultParameterSetName = "ByFile")]
    param (

        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]$Name,

        [parameter(Mandatory = $true, ParameterSetName = "ByFile")]
        [ValidateNotNullOrEmpty()]
        [String]$Path,

        [parameter(Mandatory = $true, ParameterSetName = "ByXML")]
        [ValidateNotNullOrEmpty()]
        [System.Xml.XmlDocument]$XML
    )

    # Get Edge View
    $EdgeView = Get-EdgeView -Name $Name

    # Upload XML Config
    try {

        switch ($PsCmdlet.ParameterSetName) {
            'ByFile' {
                Write-Verbose "Import-EdgeServicesXML called using ParameterSetName: ByFile"
                # Test XML path exists
                if (!(Test-Path -Path $Path)) {
                    throw "$Path not found"
                }

                # Load XML
                [XML]$Body = Get-Content -Path $Path
            }
            'ByXML' {
                Write-Verbose "Import-EdgeServicesXML called using ParameterSetName: ByXML"
                [XML]$Body = $XML
            }
            Default {throw "Import-EdgeServicesXML ParameterSetName not found"}
        }

        # Upload new VPN XML Edge config
        $Uri = ($EdgeView.Href + "/action/configureServices")

        # Set headers
        $Headers = @{
            "x-vcloud-authorization" = $EdgeView.Client.SessionKey
            "Accept"                 = "application/*+xml;version=5.1"
            "Content-Type"           = "application/vnd.vmware.admin.edgeGatewayServiceConfiguration+xml"
        }

        # Upload XML
        Write-Host -ForegroundColor yellow "Updating Edge Gateway Service configuration for $Name" -NoNewline
        $Response = Invoke-RestMethod -URI $Uri -Method POST -Headers $Headers -Body $Body

    }
    catch [Exception] {
        throw "Error updating Edge Gateway $Name."
    }

    # Get Task progress
    $TaskResult = Get-TaskStatus $Response.Task.href
    Write-Host -ForegroundColor green "`nEdge Gateway Service configuration update task complete.`nTask Details:"
    $TaskResult.Task | Select-Object operation, startTime, endTime, status | Format-List
}

function Import-EdgeFullXML {
    <#
    .SYNOPSIS
        Imports vCloud Edge full XML configuration into vCloud
    .DESCRIPTION
        Imports vCloud Edge full XML configuration to vCloud via the API
    .EXAMPLE
        Connect-CIServer api.vcd.portal.skyscapecloud.com
        Import-EdgeFullXML -Name "Edge01" -Path "C:\Path\To\EdgeXML\Edge01\Edge01_BACKUP_2016-12-08_16-37.xml"
    .EXAMPLE
        Import-EdgeFullXML -Name "Edge01" -XML $EdgeXML
    .NOTES
        Author: Adam Rush
        Created: 2016-12-08
    #>

    [CmdletBinding(DefaultParameterSetName = "ByFile")]
    param (

        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]$Name,

        [parameter(Mandatory = $true, ParameterSetName = "ByFile")]
        [ValidateNotNullOrEmpty()]
        [String]$Path,

        [parameter(Mandatory = $true, ParameterSetName = "ByXML")]
        [ValidateNotNullOrEmpty()]
        [System.Xml.XmlDocument]$XML
    )

    # Get Edge View
    $EdgeView = Get-EdgeView -Name $Name

    # Upload new VPN XML Edge config
    try {

        switch ($PsCmdlet.ParameterSetName) {
            'ByFile' {
                Write-Verbose "Import-EdgeFullXML called using ParameterSetName: ByFile"
                # Test XML path exists
                if (!(Test-Path -Path $Path)) {
                    throw "$Path not found"
                }

                # Load XML
                [XML]$Body = Get-Content -Path $Path
            }
            'ByXML' {
                Write-Verbose "Import-EdgeFullXML called using ParameterSetName: ByXML"
                [XML]$Body = $XML
            }
            Default {throw "Import-EdgeFullXML ParameterSetName not found"}
        }

        # Get Href
        $Uri = ($EdgeView.Href)

        # Set headers
        $Headers = @{
            "x-vcloud-authorization" = $EdgeView.Client.SessionKey
            "Accept"                 = "application/*+xml;version=5.1"
            "Content-Type"           = "application/vnd.vmware.admin.edgeGateway+xml"
        }

        # Upload XML
        Write-Host -ForegroundColor yellow "Updating full Edge Gateway configuration for $Name" -NoNewline
        $Response = Invoke-RestMethod -uri $Uri -Method PUT -Headers $Headers -Body $Body

    }
    catch [Exception] {
        throw $_.Exception.Message
    }

    # Get Task progress
    $TaskResult = Get-TaskStatus $Response.Task.href
    Write-Host -ForegroundColor green "`nFull Edge Gateway configuration update task complete.`nTask Details:"
    $TaskResult.Task | Select-Object operation, startTime, endTime, status | Format-List
}

function Get-TaskStatus {
    <#
    .SYNOPSIS
        Gets vCloud task status.
    .DESCRIPTION
        Gets vCloud task status and monitors until complete.
    .EXAMPLE
        Get-TaskStatus $TaskHref
    .NOTES
        Author: Adam Rush
        Created: 2016-12-08
    #>

    [CmdletBinding()]
    Param (

        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]$TaskHref
    )

    # Set headers
    $Headers = @{
        "x-vcloud-authorization" = $global:DefaultCIServers[0].SessionSecret
        "Accept"                 = "application/*+xml;version=5.1"
    }

    # Get Task progress
    try {
        do {
            $Task = Invoke-RestMethod -URI $TaskHref -Method GET -Headers $Headers
            Write-Host -ForegroundColor yellow "." -NoNewline
            Start-Sleep 2
        } while ($Task.Task.status -eq "running")

    }
    catch [Exception] {
        throw "Error finding Task."
    }

    return $Task
}

function Start-EdgeRedeploy {
    <#
    .SYNOPSIS
       Redeploys Edge.
    .DESCRIPTION
       Redeploys Edge and monitors task until complete.
    .PARAMETER EdgeView
        EdgeView object for Redeploy method.
    .EXAMPLE
       Start-EdgeRedeploy $EdgeView
    .NOTES
        Author: Adam Rush
        Created: 2016-12-08
    #>

    [CmdletBinding()]
    param (

        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [VMware.VimAutomation.Cloud.Views.Gateway]$EdgeView
    )

    # Redeploy Edge
    Write-Host -ForegroundColor yellow "Redeploying Edge Gateway $($EdgeView.Name)"
    $Task = $EdgeView.Redeploy_Task()

    # Get Task progress
    $TaskResult = Get-TaskStatus $Task.href
    Write-Host -ForegroundColor green "`nEdge Redeploy task complete.`nTask Details:"
    $TaskResult.Task | Select-Object operation, startTime, endTime, status | Format-List
}

function Confirm-EdgeDefaultGateway {
    <#
    .SYNOPSIS
        Prompts user to confirm correct Default Gateway IP address.
    .DESCRIPTION
        Prompts user to confirm correct Default Gateway IP address by enumerating all
        Interface Gateway IP addresses from the Edge XML object.
    .PARAMETER EdgeXML
        Provide an EdgeXML object
    .EXAMPLE
        $DefaultGatewayIP = Confirm-EdgeDefaultGateway $EdgeXML
    .NOTES
        Author: Adam Rush
        Created: 2016-12-09
    #>

    [CmdletBinding()]
    [OutputType('System.String')]
    param (

        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.Xml.XmlDocument]$EdgeXML
    )

    Write-Host -ForegroundColor Yellow "Default Gateway IP options for [$($EdgeXML.EdgeGateway.name)] are: "

    # Get Gateway Interface
    $GatewayInterface = $EdgeXML.EdgeGateway.Configuration.GatewayInterfaces.GatewayInterface | Where-Object {$_.UseForDefaultRoute -eq "true"}

    # Get Interface IP addresses
    $IPAdresses = $GatewayInterface.SubnetParticipation | Select-Object -ExpandProperty Gateway
    if ($IPAdresses -is [string]) {$IPAdresses = @($IPAdresses)}

    # Build menu and prompt user
    $Menu = @{}
    for ($i = 0; $i -lt $IPAdresses.count; $i++) {
        Write-Host "$i. $($IPAdresses[$i-1])"
        $Menu.Add($i, ($IPAdresses[$i - 1]))
    }
    [int]$IP = Read-Host "`nPlease select the correct option number from the list above"
    $DefaultGatewayIP = $menu.Item($IP)

    return $DefaultGatewayIP
}

function Initialize-EdgeXML {
    <#
    .SYNOPSIS
        Prepares XML Edge Configurations.
    .DESCRIPTION
        Prepares XML Edge Configurations into separate XML configurations for reparticipation.
    .PARAMETER EdgeXML
        Provide a full EdgeXML object
    .PARAMETER DefaultGatewayIP
        Provide the correct Default Gateway IP Address
    .EXAMPLE
        Initialize-EdgeXML -EdgeXML_Full $EdgeXML -DefaultGatewayIP $DefaultGatewayIP
    .NOTES
        Author: Adam Rush
        Created: 2016-12-14
    #>

    [CmdletBinding()]
    [OutputType('System.Management.Automation.PSObject')]
    param (

        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.Xml.XmlDocument]$EdgeXML_Full,

        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$DefaultGatewayIP
    )

    # Export full Edge XML
    Write-Host -ForegroundColor Yellow "Exporting Edge XML configuration for: $Name"
    Export-EdgeXML $EdgeXML_Full -Type FULL

    # Prepare Full with selected SubnetParticipation section and without EdgeGatewayServiceConfiguration section
    # Clone XML so original is unaffected (Standard assignment is by reference)
    [xml]$EdgeXML_Participate = $EdgeXML_Full.OuterXml

    # Cut EdgeGatewayServiceConfiguration section into separate XML doc (for faster reparticipation attempts)
    $EdgeGatewayServiceConfiguration_Node = $EdgeXML_Participate.EdgeGateway.Configuration.EdgeGatewayServiceConfiguration
    $RemovedServiceConfiguration_Node = $EdgeGatewayServiceConfiguration_Node.ParentNode.RemoveChild($EdgeGatewayServiceConfiguration_Node)
    Write-Verbose "Removed ServiceConfigurationNode:`n $($RemovedServiceConfiguration_Node.OuterXML)"

    # Prepare blank "all services disabled" EdgeGatewayServiceConfiguration section
    # Prepare separate EdgeGatewayServiceConfiguration section
    # Prepare new XML object for EdgeGatewayServiceConfiguration
    [xml]$EdgeGatewayServiceConfigurationXML_Disable = New-Object system.Xml.XmlDocument
    $EdgeGatewayServiceConfigurationXML_Disable_String = @"
<?xml version="1.0" encoding="UTF-8"?>
<EdgeGatewayServiceConfiguration xmlns="http://www.vmware.com/vcloud/v1.5">
	<GatewayDhcpService>
		<IsEnabled>false</IsEnabled>
	</GatewayDhcpService>
	<FirewallService>
		<IsEnabled>false</IsEnabled>
	</FirewallService>
    <NatService>
		<IsEnabled>false</IsEnabled>
	</NatService>
	<GatewayIpsecVpnService>
		<IsEnabled>false</IsEnabled>
	</GatewayIpsecVpnService>
	<StaticRoutingService>
		<IsEnabled>false</IsEnabled>
	</StaticRoutingService>
</EdgeGatewayServiceConfiguration>
"@

    # Load XML
    $EdgeGatewayServiceConfigurationXML_Disable.LoadXml($EdgeGatewayServiceConfigurationXML_Disable_String)
    Write-Verbose "EdgeGatewayServiceConfigurationXML_Disable:`n $($EdgeGatewayServiceConfigurationXML_Disable)"


    # Prepare separate EdgeGatewayServiceConfiguration section
    # Prepare new XML object for EdgeGatewayServiceConfiguration
    [xml]$EdgeGatewayServiceConfigurationXML_Enable = New-Object system.Xml.XmlDocument

    $EdgeGatewayServiceConfigurationXMLString = @"
<?xml version="1.0" encoding="UTF-8"?>
<EdgeGatewayServiceConfiguration xmlns="http://www.vmware.com/vcloud/v1.5">
$($EdgeGatewayServiceConfiguration_Node.InnerXml)
</EdgeGatewayServiceConfiguration>
"@
    # Load XML
    $EdgeGatewayServiceConfigurationXML_Enable.LoadXml($EdgeGatewayServiceConfigurationXMLString)
    Write-Verbose "EdgeXML EdgeGatewayServiceConfiguration:`n $($EdgeGatewayServiceConfigurationXML_Enable)"

    # Prepare Full without selected SubnetParticipation section and without EdgeGatewayServiceConfiguration section
    # Cut SubnetParticipation section (that contains correct Gateway IP) and save new XML
    [xml]$EdgeXML_UnParticipate = $EdgeXML_Participate.OuterXml
    $GatewayInterface = $EdgeXML_UnParticipate.EdgeGateway.Configuration.GatewayInterfaces.GatewayInterface | Where-Object {$_.UseForDefaultRoute -eq "true"}
    $SubnetParticipationNode = $GatewayInterface.SubnetParticipation | Where-Object {$_.Gateway -eq $DefaultGatewayIP}
    $RemovedNode = $SubnetParticipationNode.ParentNode.RemoveChild($SubnetParticipationNode)
    Write-Verbose "Removed SubnetParticipationNode:`n $($RemovedNode.OuterXML)"


    # Export Disable EdgeGateway Service Configuration
    Write-Host -ForegroundColor Yellow "Exporting 'Disable EdgeGateway Service Configuration' for: $Name"
    Export-EdgeXML $EdgeGatewayServiceConfigurationXML_Disable -Type EdgeGatewayServiceConfigurationXML_Disable

    # Export Disable EdgeGateway Service Configuration
    Write-Host -ForegroundColor Yellow "Exporting 'Enable EdgeGateway Service Configuration' for: $Name"
    Export-EdgeXML $EdgeGatewayServiceConfigurationXML_Enable -Type EdgeGatewayServiceConfigurationXML_Enable

    # Export Edge XML with removed subnet and no EdgeGateway Service Configuration
    Write-Host -ForegroundColor Yellow "Exporting 'EdgeXML_UnParticipate' with no EdgeGateway Service Configuration for: $Name"
    Export-EdgeXML $EdgeXML_UnParticipate -Type EdgeXML_UnParticipate

    # Export Edge XML with all subnets and no EdgeGateway Service Configuration
    Write-Host -ForegroundColor Yellow "Exporting 'EdgeXML_Participate' with no EdgeGateway Service Configuration for: $Name"
    Export-EdgeXML $EdgeXML_Participate -Type EdgeXML_Participate


    # Assign and return prepared XML objects
    $ReturnXML = [pscustomobject]@{
        EdgeGatewayServiceConfigurationXML_Disable = $EdgeGatewayServiceConfigurationXML_Disable
        EdgeGatewayServiceConfigurationXML_Enable  = $EdgeGatewayServiceConfigurationXML_Enable
        EdgeXML_UnParticipate                      = $EdgeXML_UnParticipate
        EdgeXML_Participate                        = $EdgeXML_Participate
    }

    return $ReturnXML

}

function Start-EdgeReparticipate {
    <#
    .SYNOPSIS
        Reparticipates an Edge.
    .DESCRIPTION
        Reparticipates an Edge until the correct Default Gateway IP address is applied.
    .PARAMETER Name
        Specify a single vShield Edge name. Use quotes if the name includes spaces.
    .PARAMETER VSMServer
        Specify a single vShield Manager name.
    .EXAMPLE
        Start-EdgeReparticipate -Name "Edge01" -VSMServer "vShieldManager01"
    .NOTES
        Author: Adam Rush
        Created: 2016-12-09
    #>

    [CmdletBinding()]
    param (

        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$VSMServer
    )

    # Get Edge View and XML
    $EdgeView = Get-EdgeView -Name $Name
    $EdgeXML = Get-EdgeXML $EdgeView
    Write-Verbose "EdgeXML loaded for:`n $Name"

    # Prompt user for correct Default Gateway IP address
    $DefaultGatewayIP = Confirm-EdgeDefaultGateway $EdgeXML
    Write-Verbose "Confirmed Default Gateway IP is: $DefaultGatewayIP"

    # Check Edge default gateway IP via VSM
    Connect-vShieldManager -Server $VSMServer
    $VSMEdge = Get-VSMEdge -EdgeName $Name -Server $VSMServer
    $VSMEdgeXML = Get-VSMEdgeXML $VSMEdge
    $VSMEdgeGatewayIP = $VSMEdgeXML.edge.features.staticRouting.defaultRoute.gatewayAddress
    Write-Verbose "VSM Default Edge Gateway IP is: $VSMEdgeGatewayIP"

    # Exit if IPs match already
    if ($VSMEdgeGatewayIP -eq $DefaultGatewayIP) {
        Write-Host -ForegroundColor Green "Default Gateway IP is already correct for [$Name].`nExiting script..."
        return
    }
    else {
        # VSM Edge Default Gateway is wrong, so reparticipate
        Write-Host -ForegroundColor Yellow "Default Gateway is wrong, currently [$VSMEdgeGatewayIP] but should be [$DefaultGatewayIP]."
    }

    # Compare Default Gateway IPs and reparticipate until correct
    $ReparticipateAttemptCounter = 0
    $ReparticipateAttemptMax = 10

    # Prepare Edge XML
    $EdgeXML_Configs = Initialize-EdgeXML -EdgeXML_Full $EdgeXML -DefaultGatewayIP $DefaultGatewayIP

    try {
        # STEP 1 - Disable EdgeGatewayServiceConfiguration
        Write-Host -ForegroundColor Yellow "STEP 1:`nRemoving Edge Gateway Service Configuration for: [$Name]`n"
        Import-EdgeServicesXML -Name $Name -XML $EdgeXML_Configs.EdgeGatewayServiceConfigurationXML_Disable

        # STEP 2 - Reparticipate Edge
        # Start reparticipate loop
        Write-Host -ForegroundColor Yellow "STEP 2:`nStarting reparticipate loop for: [$Name]`n"
        while ($VSMEdgeGatewayIP -ne $DefaultGatewayIP) {
            Write-Verbose "Reparticipate Attempt [$ReparticipateAttemptCounter] started...`n"

            # UNPARTICIPATE Edge
            Write-Host -ForegroundColor Yellow "UnParticipating Edge (Removing Gateway Interface Subnet) for: [$Name]"
            Import-EdgeFullXML -Name $Name -XML $EdgeXML_Configs.EdgeXML_UnParticipate

            # PARTICIPATE Edge
            Write-Host -ForegroundColor Yellow "Participating Edge (Adding Gateway Interface Subnet) for: [$Name]`n"
            Import-EdgeFullXML -Name $Name -XML $EdgeXML_Configs.EdgeXML_Participate

            # Check VSM Edge Default Gateway IP
            $VSMEdgeXML = Get-VSMEdgeXML $VSMEdge
            $VSMEdgeGatewayIP = $VSMEdgeXML.edge.features.staticRouting.defaultRoute.gatewayAddress
            Write-Verbose "VSM Default Edge Gateway IP is: $VSMEdgeGatewayIP`n"

            # Compare Default Gateway IPs and restore Edge Services Config (VPN/SR etc) if the same
            if ($VSMEdgeGatewayIP -eq $DefaultGatewayIP) {
                Write-Host -ForegroundColor Green "Default Gateway IP now correct for: [$Name]`n"
                break
            }

            if ($ReparticipateAttemptCounter -ge $ReparticipateAttemptMax) {
                # Break out of loop
                Write-Warning "Maximum Reparticipation Attempts of [$ReparticipateAttemptMax] reached...`n"
                break
            }

            # Increment counter
            $ReparticipateAttemptCounter++
            Write-Verbose "Reparticipate Attempt [$ReparticipateAttemptCounter] complete.`n"
        }

        # STEP 3 - Restore EdgeGatewayServiceConfiguration
        Write-Host -ForegroundColor Yellow "STEP 3:`nRestoring Edge Gateway Service Configuration for: [$Name]`n"
        Import-EdgeServicesXML -Name $Name -XML $EdgeXML_Configs.EdgeGatewayServiceConfigurationXML_Enable

        Write-Host -ForegroundColor Green "Reparticipation complete for: [$Name]`n"
    }
    catch [Exception] {
        Write-Warning "ERROR OCCURRED:`nRestoring Original Edge Gateway Configuration for: [$Name]`n"
        Import-EdgeFullXML -Name $Name -XML $EdgeXML
    }

    # TODO - show complete task duration, and maybe backup file location, with ad-hoc FULL restore command?

}

## vShield Manager Functions ##
function Connect-vShieldManager {
    <#
    .SYNOPSIS
        Connects to vShield Manager.
    .DESCRIPTION
        Connects to vShield Manager and saves connection object in $Global.
    .PARAMETER Server
        vShield Manager to connect to.
    .EXAMPLE
        Connect-vShieldManager -Server vShieldManager01
    .NOTES
        Author: Adam Rush
        Created: 2016-12-09
    #>

    [CmdletBinding()]
    param (

        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Server
    )

    # Accept untrusted SSL cert
    if ( -not ("TrustAllCertsPolicy" -as [type])) {

        Add-Type @"
            using System.Net;
            using System.Security.Cryptography.X509Certificates;
            public class TrustAllCertsPolicy : ICertificatePolicy {
                public bool CheckValidationResult(
                    ServicePoint srvPoint, X509Certificate certificate,
                    WebRequest request, int certificateProblem) {
                    return true;
                }
            }
"@
    }
    [System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy

    # Check for vShield Manager connection
    if (-not $Global:VSMConnection.Token) {

        # Prompt for login credentials
        $Cred = Get-Credential -Message "Login to vShield Manager..."
        $User = $Cred.getNetworkCredential().Username
        $Pass = $Cred.getNetworkCredential().Password
        $Auth = 'Basic ' + [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes("${User}:${Pass}"))

        # Create connection Object
        $Global:VSMConnection = [pscustomobject]@{
            Username = $User
            Server   = $Server
            Token    = $Auth
        }
    }

    # Update Server
    $Global:VSMConnection.Server = $Server

    # Test connection to vShield Manager
    try {
        Write-Verbose "Logging into $($Global:VSMConnection.Server) API..."

        $Uri = "https://$($Global:VSMConnection.Server)/api/2.0/global/heartbeat/"
        $Headers = @{"AUTHORIZATION" = $Global:VSMConnection.Token}
        [xml]$VSMVersionXML = Invoke-RestMethod -Method GET -Uri $Uri -Headers $Headers -ContentType "text/xml"

        # Show returned version
        Write-Verbose $VSMVersionXML

    }
    catch [Exception] {
        throw "Error connecting to $($Global:VSMConnection.Server). Check credentials."
    }

    $VSMConnection
}

function Get-VSMEdge {
    <#
    .SYNOPSIS
        Gets the Edge ID from vShield Manager.
    .DESCRIPTION
        Gets the Edge ID from vShield Manager (VSM) via REST API.
    .PARAMETER EdgeName
        Specify a single vShield Edge name. Use quotes if the name includes spaces.
    .PARAMETER Server
        Specify a single vShield Manager name.
    .EXAMPLE
        Connect-vShieldManager -Server vShieldManager01
        Get-VSMEdge -EdgeName "Edge01" -Server "vShieldManager01"
    .NOTES
        Author: Adam Rush
        Created: 2016-12-09
    #>

    [CmdletBinding()]
    param (

        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$EdgeName,

        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Server
    )

    # Check for vShield Manager connection
    if (-not $Global:VSMConnection) {
        throw "Please connect to vShield Manager before using this function, eg. Connect-vShieldManager -Server vShieldManager01"
    }

    # Get all Edges
    try {
        Write-Host -ForegroundColor Yellow "Logging into $Server API..."
        Write-Host -ForegroundColor Yellow "Retrieving all Edges from $($Server)...`n"

        $Uri = "https://$Server/api/3.0/edges/"
        $Headers = @{"AUTHORIZATION" = $Global:VSMConnection.Token}
        [xml]$EdgesXML = Invoke-RestMethod -Method GET -Uri $Uri -Headers $Headers -ContentType "text/xml"

        # Find single Edge
        $Edge = $EdgesXML.pagedEdgeList.edgePage.edgeSummary | Where-Object {$_.name -match $EdgeName}

    }
    catch [Exception] {
        throw "Edge Gateway $EdgeName not found."
    }

    # Test for null object
    if ($Edge -eq $null) {
        throw "Edge Gateway result is NULL."
    }

    # Test for 1 returned object
    if ($Edge.Count -gt 1) {
        throw "More than 1 Edge Gateway found."
    }

    # Create VSMEdge Object
    $VSMEdge = [pscustomobject]@{
        ID     = $Edge.id
        Name   = $EdgeName
        Server = $Server
    }

    return $VSMEdge
}

function Get-VSMEdgeXML {
    <#
    .SYNOPSIS
        Gets the Edge XML from vShield Manager.
    .DESCRIPTION
        Gets the Edge XML from vShield Manager (VSM) using the Edge ID via REST API.
    .PARAMETER VSMEdge
        Provide a VSMEdge object
    .EXAMPLE
        Connect-vShieldManager -Server vShieldManager01
        $VSMEdge = Get-VSMEdge -EdgeName "Edge01" -Server "vShieldManager01"
        Get-VSMEdgeXML $VSMEdge
    .NOTES
        Author: Adam Rush
        Created: 2016-12-09
    #>

    [CmdletBinding()]
    param (

        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [pscustomobject]$VSMEdge
    )

    # Check for vShield Manager connection
    if (-not $Global:VSMConnection) {
        throw "Please connect to vShield Manager before using this function, eg. Connect-vShieldManager -Server vShieldManager01"
    }

    # Get all Edges
    try {
        Write-Verbose "Logging into $($Global:VSMConnection.Server) API..."
        Write-Host -ForegroundColor Yellow "Getting Edge XML for $($VSMEdge.Name) ($($VSMEdge.id))...`n"

        # Get Edge XML using id property
        $Uri = "https://$($Global:VSMConnection.Server)/api/3.0/edges/$($VSMEdge.ID)"
        $Headers = @{"AUTHORIZATION" = $Global:VSMConnection.Token}

        Write-Verbose "Querying API URL: $Uri..."
        [xml]$EdgeXML = Invoke-RestMethod -Method GET -Uri $Uri -Headers $Headers -ContentType "text/xml"

    }
    catch [Exception] {
        throw "VSM Edge Gateway $($VSMEdge.Name) not found."
    }

    # Test for null object
    if ($EdgeXML -eq $null) {
        throw "Edge Gateway XML is NULL."
    }

    # Test for 1 returned object
    if ($EdgeXML.Count -gt 1) {
        throw "More than 1 Edge Gateway found."
    }

    return $EdgeXML
}

function Get-VSMEdgeStatusXML {
    <#
    .SYNOPSIS
        Gets the Edge Status XML from vShield Manager.
    .DESCRIPTION
        Gets the Edge Status XML from vShield Manager (VSM) using the Edge ID via REST API.
    .PARAMETER VSMEdge
        Provide a VSMEdge object
    .EXAMPLE
        Connect-vShieldManager -Server vShieldManager01
        $VSMEdge = Get-VSMEdge -EdgeName "Edge01" -Server "vShieldManager01"
        Get-VSMEdgeStatusXML $VSMEdge
    .NOTES
        Author: Adam Rush
        Created: 2016-12-09
    #>

    [CmdletBinding()]
    param (

        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [pscustomobject]$VSMEdge
    )

    # Check for vShield Manager connection
    if (-not $Global:VSMConnection) {
        throw "Please connect to vShield Manager before using this function, eg. Connect-vShieldManager -Server vShieldManager01"
    }

    # Get all Edges
    try {
        Write-Verbose "Logging into $($Global:VSMConnection.Server) API..."
        Write-Host -ForegroundColor Yellow "Getting Edge Status XML for $($VSMEdge.Name) ($($VSMEdge.id))...`n"

        # Get Edge XML using id property
        $Uri = "https://$($Global:VSMConnection.Server)/api/3.0/edges/$($VSMEdge.ID)/status?getlatest=true&detailed=true"
        $Headers = @{"AUTHORIZATION" = $Global:VSMConnection.Token}

        Write-Verbose "Querying API URL: $Uri..."
        [xml]$EdgeStatusXML = Invoke-RestMethod -Method GET -Uri $Uri -Headers $Headers -ContentType "text/xml"

    }
    catch [Exception] {
        throw "Edge Gateway $($VSMEdge.Name) not found."
    }

    # Test for null object
    if ($EdgeStatusXML -eq $null) {
        throw "Edge Gateway XML is NULL."
    }

    # Test for 1 returned object
    if ($EdgeStatusXML.Count -gt 1) {
        throw "More than 1 Edge Gateway found."
    }

    return $EdgeStatusXML
}
