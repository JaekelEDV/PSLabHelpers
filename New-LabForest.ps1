function New-LabForest {
    <#
    .SYNOPSIS
        New-LabForest quickly sets up the first DomainController
        and an Active Directory Forest in a virtual lab-environment.
        THIS CODE IS NOT FOR PRODUCTION USE!

    .DESCRIPTION
    New-LabForest installs a new Active Directory Forest
    on a virtual DomainController in a lab-environment.
    New-LabForest will do the following:
        - Configures TCP/IP-Settings (see parameters) and renames GuestOS
        - Install-WindowsFeature 'AD-Domain-Services'
        - Install-ADDSForest
        - Checks status of some some key AD components
    Requires elevation; must be running in a PowerShell session as an administrator.

    .PARAMETER VM
        The name of the VM you want to turn into a DomainController.
        You can tab to autocomplete VMs installed on the hypervisor.

    .PARAMETER ForestName
        The DNSName of the forest you want to build, e.g. test.local.

    .PARAMETER DCName
        The Name of the DomainController.
        This is build via a ValidateSet with given names. You may change this in the code.

    .PARAMETER IPv4Address
        The IPv4Address of the DomainController.
        Has a default value if you omit the param.

    .PARAMETER PrefixLength
        The subnet mask of the DomainController.
        Has a default value if you omit the param.

    .PARAMETER StandardGateway
        The Standardgateway of the DomainController.
        Has a default value if you omit the param.

    .PARAMETER DNSServer
        The preferred DNS-Server of the DomainController.
        Has a default value set to itself if you omit the param.
        Will overwrite the localhost entry after dcpromo.

    .EXAMPLE
        Dot source it or load it another way.
        New-LabForest -VM 'vMACHINE' -ForestName 'test.local' -DCName 'DC01'

    .LINK
        Online version: https://github.com/JaekelEDV/PSLabHelpers/blob/master/New-LabForest.ps1

    .NOTES
        The idea of New-LabForest is to be run against a VM with an installed Server-OS.
        You might execute it directly from the Virtualization-Host.
        You don't need network-access to the VM at all: it relies on PowerShellDirect.

        File Name: New-LabForest.ps1
        Author: Oliver Jaekel | oj@jaekel-edv.de | @JaekelEDV | https://github.com/JaekelEDV
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory = $True)]
        [string]$VM,

        [Parameter(Mandatory = $True, HelpMessage="Enter a DomainName like 'domain.tld'.")]
        [ValidatePattern(
            '(?# ForestName seems to be NO VALID DOMAINNAME, e.g. domain.tld)^([a-z0-9]+(-[a-z0-9]+)*\.)+[a-z]{2,}$')]
        [string]$ForestName,

        [Parameter(Mandatory = $True)]
        [ValidateSet('DC1', 'DC01', 'RootDC')]
        [string]$DCName,

        [Parameter()]
        [IPAddress]$IPv4Address = '10.0.0.1',

        [Parameter()]
        [ValidateRange(1, 32)]
        [int]$PrefixLength = '24',

        [Parameter()]
        [IPAddress]$StandardGateway = '10.0.0.254',

        [Parameter()]
        [IPAddress]$DNSServer = '10.0.0.1'
    )

    #region Defining some vars and getting the creds for local-admin, domain-admin and DSRM-Mode.
    $InformationPreference = 'Continue'
    $NetBIOSName = $ForestName.Split('.')[0]
    $VMName = (Get-VM -Name $VM).Name
    $LocalCreds = Get-Credential -UserName 'administrator' -Message 'Please enter Local-VM-Admin-Credentials!'
    $DomainCreds = Get-Credential -UserName "$NetBIOSName\administrator" -Message 'Please enter Domain-Admin-Credentials!'
    #Getting DSRM-Creds, extracting password, converting password to securestring
    $DSRMCreds = Get-Credential -UserName 'administrator' -Message 'Please enter DSRM-Credentials!'
    $SecureDSRMPassword = $DSRMCreds.GetNetworkCredential().Password |
    ConvertTo-SecureString -AsPlainText -Force
    #endregion

    #region Function to check if VM is already a DC (ProductType=2). If true, script will stop.
    function Test-IsDomainController {
        <#
        .SYNOPSIS
            Test if the target is a DomainController.
        .DESCRIPTION
            This function queries the CimInstance Win32_OperatingSystem.ProductType.
            Work Station (1), Domain Controller (2), Server (3).
        .EXAMPLE
            Test-IsDomainController
        .INPUTS

        .OUTPUTS

        .NOTES
        #>
        [CmdletBinding()]
        param (
        )
        $script:isDC = (Invoke-Command -VMName $VMName -Credential $DomainCreds -ScriptBlock {
                (Get-CimInstance -ClassName Win32_OperatingSystem).ProductType
            })
        if ($script:isDC -eq '2') {
            throw "The VM already is a DomainController. Better stop here..."
        }
    }
    Test-IsDomainController
    Write-Verbose "GuestOS is checked if DomainController. Result: $isDC (see help)."
    #endregion

    #region Setting TCP/IP of the DC
    ""; ""
    Write-Information -MessageData "[+]Setting TCP/IP on $DCName..."
    ""
    Invoke-Command -VMName $VMName -Credential $LocalCreds -ScriptBlock {

        $NetAdapter = @{
            InterfaceDescription = 'Microsoft Hyper-V Network Adapter'
            NewName              = 'LAN'
        }

        Rename-NetAdapter @NetAdapter
        $NetAdapterName = (Get-NetAdapter).name
        Write-Verbose "The Netadapter is renamed to $NetAdapterName"

        #In case there is already a static config, it's removed now. This avoids some annoyances.
        #netsh is preferred: easy, reliable, done.
        function  Remove-NetIPConfig {
            <#
            .SYNOPSIS
            Removes the TCP/IP and DNS settings of a machine.

            .DESCRIPTION
            The function resets the TCP/IP and DNS settings via netsh.
            Main goal is to have it clean before configuring it with desired values.

            .EXAMPLE
            Remove-NetIPConfig
            #>
            param (
            )
            #$NetAdapterName = (Get-NetAdapter).name
            $NetshDHCP = 'interface ipv4 set address name="LAN" source=dhcp'
            $NetshDNS  = 'interface ipv4 delete dnsservers name="LAN" address=all'
            Invoke-Expression "netsh $NetshDHCP"
            Invoke-Expression "netsh $NetshDNS"
        }
        Remove-NetIPConfig | Out-Null

        $NICConfig = @{
            #InterfaceAlias = 'LAN'
            InterfaceAlias = $NetAdapterName
            IPAddress      = $using:IPv4Address
            AddressFamily  = 'IPV4'
            DefaultGateway = $using:StandardGateway
            PrefixLength   = $using:PrefixLength
        }
        New-NetIPAddress @NICConfig | Out-Null

        $DNS = @{
            InterfaceAlias  = 'LAN'
            ServerAddresses = $using:DNSServer
        }
        Set-DnsClientServerAddress @DNS
        #endregion
    }
    #region Rename Guest OS and reboot it.
    Invoke-Command -VMName $VMName -Credential $LocalCreds -ScriptBlock {
        if ($using:DCName -eq $env:COMPUTERNAME) {
            Write-Information -MessageData "[+]Hostname already is $DCName - skipping rename."
        }
        else {
            Write-Information -MessageData "[+]Renaming GuestOS to $using:DCName..."
            $WarningPreference = 'SilentlyContinue'
            Rename-Computer -NewName $using:DCName -Force
            ""
        }
    }
    Write-Verbose "Network Adapter is renamed to 'LAN'."
    Write-Verbose "Pre-Existing TCP/IP config is deleted."
    Write-Verbose "TCP/IP config is done according to parameters."
    Write-Verbose "GuestOS is renamed to $DCName"

    Stop-VM -Name $VMName
    Start-VM -Name $VMName

    do {
        Write-Information -MessageData "[+]$VMName not ready. Waiting..."
        $Heartbeat = (Get-VM -Name $VMName).HeartBeat
        Start-Sleep -Seconds 3
    }

    until ($Heartbeat -eq 'OkApplicationsUnknown'-or $Heartbeat -eq 'OkApplicationsHealthy')
    [void]$Heartbeat
    ""
    Write-Information -MessageData "[+]$VMName is ready. Continuing..."
    Write-Verbose "VM status is $Heartbeat."
    #endregion

    #region Install the role for ADDS
    Invoke-Command -VMName $VMName -Credential $LocalCreds -ScriptBlock {

        $AD = Get-WindowsFeature -Name 'AD-Domain-Services' |
        Where-Object { $_.Installed -eq $true }
        if ($AD -ne $null) {
            Write-Verbose "AD-Domain-Services already installed."
        }

        else {
            ""
            Write-Information -MessageData '[+]Installing AD-Domain-Services...'
            Install-WindowsFeature -Name 'AD-Domain-Services' -IncludeManagementTools
        }
    }
    #endregion

    #region Import the needed modules.
    #Attention: ADDSDeployment is only available after installing the ADDS-Feature
    Invoke-Command -VMName $VMName -Credential $LocalCreds -ScriptBlock {
        $LoadedModules = {
            Get-Module -ListAvailable -Name ServerManager, ADDSDeployment

            if ($LoadedModules -notcontains 'ServerManager') {
                try{
                    Import-Module -Name ServerManager -ErrorAction 'Stop'
                }
                catch {
                    Write-Warning $_.Exception.Message
                    throw "That's all folks, cannot continue without this..."
                }
            }

            if ($LoadedModules -notcontains 'ADDSDeployment'){
                try {
                    Import-Module -Name 'ADDSDeployment' -ErrorAction 'Stop'
                }
                catch {
                    Write-Warning $_.Exception.Message
                    throw "That's all folks, cannot continue without this..."
                }
            }
        }
    }
    Write-Verbose "Needed modules ServerManager and ADDSDeployment are imported."
    #endregion

    #region Install DC, first in new Forest, FunctionalLevel Server 2012 R2: 6, Server 2016: 7
    Invoke-Command -VMName $VMName -Credential $LocalCreds -ScriptBlock {

        $Params = @{
            DatabasePath                  = 'C:\Windows\NTDS'
            LogPath                       = 'C:\Windows\NTDS'
            SysvolPath                    = 'C:\Windows\SYSVOL'
            DomainName                    = $using:ForestName
            DomainNetbiosName             = $using:NetBIOSName
            SafeModeAdministratorPassword = $using:SecureDSRMPassword
            ForestMode                    = 7
            DomainMode                    = 7
            InstallDns                    = $true
            NoDnsOnNetwork                = $true
            CreateDnsDelegation           = $false
            NoRebootOnCompletion          = $true
            Confirm                       = $false
            Force                         = $true
            WarningAction                 = 'SilentlyContinue' #Suppresses "Standard"-Warnings, i.e. DNS-Deleg., Crypto-Algo. etc.
        }

        Install-ADDSForest @Params

        Write-Verbose "Forest Install successfully completed."

        #In case you don't like the localhost-addresses for DNS - these lines
        #will revert the IPv4 to the own server-address and IPv6 switched to automatic (eg. fe80).
        Set-DnsClientServerAddress -InterfaceAlias 'LAN' -ResetServerAddresses
        Set-DnsClientServerAddress -InterfaceAlias 'LAN' -ServerAddresses $using:DNSServer
        #endregion
    }
    #region Rebooting VM and pausing the script to give the system some time.
    Stop-VM -Name $VMName
    Start-VM -Name $VMName

    do {
        Write-Information -MessageData "[+]$VMName not ready. Waiting..."
        $Heartbeat = (Get-VM -Name $VMName).HeartBeat
        Start-Sleep -Seconds 3
    }

    until ($Heartbeat -eq 'OkApplicationsUnknown'-or $Heartbeat -eq 'OkApplicationsHealthy')
    [void]$Heartbeat
    ""
    Write-Information -MessageData "[+]$VMName is ready. Giving the system some time..."
    Write-Verbose "VM status is $Heartbeat."
    ""
    $sec = 60
    1..$sec |
    ForEach-Object {
        Write-Progress -Activity "Dreaming of electric sheep..." -Status "$($sec - $_) seconds remaining..."
        Start-Sleep -Seconds 1
    }
    #endregion

    #region Checking status of some key AD components
    Write-Information -MessageData "[+]Checking status of Active Directory..."
    ""
    do {
        Write-Information -MessageData "[+]Waiting for $DCName listening on Port 389..."
        ""
        Start-Sleep -Seconds 1
    }

    until (Invoke-Command -VMName $VMName -Credential $DomainCreds -ScriptBlock {
            (Test-NetConnection -ComputerName $using:DCName -Port 389 |
                Where-Object { $_.TcpTestSucceeded } )
        })

    Write-Information -MessageData "[+]$DCName is listening on Port 389..."
    ""

    do {
        Write-Information -MessageData "[+]Waiting for AD WebServices..."
        ""
        Start-Sleep -Seconds 1
    }

    until (Invoke-Command -VMName $VMName -Credential $DomainCreds -ScriptBlock {
            (Get-Service -Name 'adws' | Where-Object { $_.status -eq 'running' })
        })

    Write-Information -MessageData "[+]AD WebServices are ready..."
    ""

    Write-Information -MessageData "[+]Checking DNS-Server..."
    ""
    Invoke-Command -VMName $VMName -Credential $DomainCreds -ScriptBlock {

        if (Test-DnsServer -IPAddress $using:IPv4Address -WarningAction 'SilentlyContinue') {
            Write-Information -MessageData "[+]DNS-Server is functional."
            ""
        }

        (Get-Service adws, kdc, netlogon, dns -WarningAction 'SilentlyContinue' |
            Out-String).Trim()
        ""
        #The following is done because sometimes the machine refuses to set
        #the right firewall profile (domain) for the vNIC. Sometimes this helps...
        #You might play with these lines or simply omit them.
        Restart-Service -Name nlasvc -Force

        $NetAdapterName = (Get-NetAdapter).Name
        Disable-NetAdapter -Name $NetAdapterName -Confirm:$false
        Start-Sleep -Seconds 2
        Enable-NetAdapter -Name $NetAdapterName -Confirm:$false
    }

    Write-Information -MessageData "[+]Active Directory is ready."
    ""
    Write-Information -MessageData "[+]Forest $ForestName is hosted on $DCName"
    ""
    Write-Information -MessageData "[+]You'll still have to wait a moment for logon."
    #endregion

}

#region Register Argumentcompleter let's you tab out all your VMs.
$GetVM = { Get-VM | Select-Object -ExpandProperty Name }

$AutoCompleteVM = @{
    CommandName   = 'New-LabForest'
    ParameterName = 'VM'
    ScriptBlock   = $GetVM
}
Register-ArgumentCompleter @AutoCompleteVM
#endregion
