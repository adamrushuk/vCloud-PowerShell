# Set Edge Syslog server
<#
Connect-CIServer -Server vCloudServer01
PowerCLI C:\> $EdgeView  | Get-Member -MemberType method

   TypeName: VMware.VimAutomation.Cloud.Views.Gateway

Name                               MemberType Definition
----                               ---------- ----------
ConfigureSyslogServerSettings      Method     void ConfigureSyslogServerSettings(VMware.VimAutomation.Cloud.Views.TenantSyslogServerSettings tenantSyslogServerSettings)
#>

$EdgeView = Search-Cloud -QueryType EdgeGateway -Name 'Edge01' | Get-CIView

$TenantSyslogServerSettings = New-Object VMware.VimAutomation.Cloud.Views.TenantSyslogServerSettings
$TenantSyslogServerSettings.SyslogServerIp = 10.10.10.10
$EdgeView.ConfigureSyslogServerSettings($TenantSyslogServerSettings)
$EdgeView.UpdateServerData()