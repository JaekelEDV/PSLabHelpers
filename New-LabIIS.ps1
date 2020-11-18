function New-LabIIS {
    <#
    .SYNOPSIS
        New-LabIIS quickly sets up an IIS-Webserver in a virtual lab-environment.
        THIS CODE IS NOT FOR PRODUCTION USE!

    .DESCRIPTION
    New-LabIIS sets up an IIS-Webserver in a virtual lab-environment.
    New-LabIIS will do the following:
        - Install the IIS-Role
        - Install a set of Role-Services (hardcoded, without dev-components)
    Requires elevation; must be running in a PowerShell session as an administrator.

    .PARAMETER VM
        The name of the VM you want to install the IIS on.
        You can tab to autocomplete VMs installed on the hypervisor.

    .EXAMPLE
        Dot source it or load it another way.
        New-LabIIS -VM 'vMACHINE'

    .LINK
        Online version: https://github.com/JaekelEDV/

    .NOTES
        The idea of New-LabIIS is to be run against a VM with an installed Server-OS.
        You might execute it directly from the Virtualization-Host.
        You don't need network-access to the VM at all: it relies on PowerShellDirect.

        If you should miss some role-services, the following are not installed.
        Simply add them to the $IISFeatures variable in the scriptblock.

        RDS-Web-Access
        Web-Application-Proxy
        Web-DAV-Publishing
        Web-Net-Ext
        Web-AppInit
        Web-Asp-Net
        Web-CGI
        Web-Includes
        Web-WebSockets
        Web-Ftp-Server
        Web-Ftp-Service
        Web-Ftp-Ext
        Web-Lgcy-Scripting
        Web-WMI
        Web-WHC
        WebDAV-Redirector
        WindowsPowerShellWeb

        File Name: New-LabIIS.ps1
        Author: Oliver Jaekel | oj@jaekel-edv.de | @JaekelEDV | https://github.com/JaekelEDV
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $True, HelpMessage="Enter the Name of the VM you want to install IIS to.")]
        [string]$VM
    )
    #Requires -RunAsAdministrator

    $DomainCreds = Get-Credential -UserName 'test\administrator' -Message 'Please enter Domain-Admin-Credentials!'

    Invoke-Command -VMName $VM -Credential $DomainCreds -ScriptBlock {

        $IISFeatures = "ADCS-Enroll-Web-Pol", "ADCS-Enroll-Web-Svc", "ADCS-Web-Enrollment", "Web-Server", "Web-WebServer", "Web-Common-Http", "Web-Http-Errors", "Web-Default-Doc", "Web-Static-Content", "Web-Dir-Browsing", "Web-Http-Redirect", "Web-Performance", "Web-Stat-Compression", "Web-Dyn-Compression", "Web-Security", "Web-Filtering", "Web-Client-Auth", "Web-Cert-Auth", "Web-Digest-Auth", "Web-IP-Security", "Web-Basic-Auth", "Web-CertProvider", "Web-Url-Auth", "Web-Windows-Auth", "Web-Health", "Web-Http-Logging", "Web-Http-Tracing", "Web-Request-Monitor", "Web-Custom-Logging", "Web-ODBC-Logging", "Web-Log-Libraries", "Web-Mgmt-Tools", "Web-Mgmt-Console", "Web-Scripting-Tools", "Web-Mgmt-Service"
        try {
            Install-WindowsFeature -Name $IISFeatures -IncludeManagementTools
        }

        catch {
            Write-Warning $_.Exception.Message
        }
    }
}

#region Register Argumentcompleter let's you tab out all your VMs.
$GetVM = { Get-VM | Select-Object -ExpandProperty Name }

$AutoCompleteVM = @{
    CommandName   = 'New-LabIIS'
    ParameterName = 'VM'
    ScriptBlock   = $GetVM
}
Register-ArgumentCompleter @AutoCompleteVM
#endregion
