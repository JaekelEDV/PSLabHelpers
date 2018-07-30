<#
.SYNOPSIS
    Function New-LabNCSI configures a server as IIS and DNS to support
    Network Connectivity Status Indicator (NCSI) scenarios for lab environments.
.DESCRIPTION
    In some lab environments some machines really need to think they're on the internet,
    e.g. a Direct Access scenario. Most of my labs won't have internet access b/c I like to keep the VMs "sandboxed".
    This function helps you to turn a machine into a IIS- and DNS-
    Server simulating Microsofts Network Connectivity Status Indicator technique.
    To avoid touching the registry of the clients that will use this machine, the default MS
    domains and files have not been altered.
    Since Client OS might either use msftncsi.com (Win8.1 and earlier) or msftconnecttest.com (Win10), both is configured.
    Find more on NCSI under the link section of this help.
    This function is meant to be run on a Windows Server OS (tested with 2016) and does the following:
    Installs IIS with default settings and creates ncsi.txt and connecttest.txt in inetpub\wwwroot.
    Installs DNS and creates the two zones msftncsi.txt and msftconnecttest.com.
    Creates the necessary Host(A) records (www and dns).
    Sets the preferred DNS-Server to itself - be aware of this one!!!
    Sets a new default route to localhost if there is no default gateway - otherwise ncsi won't work at all.
    As a result you get a machine thinking it has real internet connection. All Clients pointing to
    this machine will change their network connectivity status to "internet connected" as well.
.EXAMPLE
    Execute New-LabNCSI.ps1 directly from shell with dot sourcing
    . .\New-LabNCSI.ps1
.LINK
    https://blogs.technet.microsoft.com/networking/2012/12/20/the-network-connection-status-icon/
.LINK
    https://blogs.technet.microsoft.com/netgeeks/2018/02/20/why-do-i-get-an-internet-explorer-or-edge-popup-open-when-i-get-connected-to-my-corpnet-or-a-public-network/
.NOTES
    Author: Oliver Jäkel | oj@jaekel-edv.de | @JaekelEDV | https://github.com/JaekelEDV
#>

Function New-LabNCSI
{
    [CmdletBinding()]
    param (
        $InformationPreference = 'Continue',
        $WarningPreference = 'Stop'
    )

    BEGIN
    {
        #region Check if script is run as administrator.

        if
        (([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))

        {
            Write-Verbose -Message 'Check: You are Admin and good to go.'
        }
        else
        {
            Write-Warning -Message 'Please run Powershell as Administrator - script will not continue.'
        }
        #endregion

        #region Check if IIS is installed - if not: Make it so!
        $IIS = Get-WindowsFeature -Name web-server | Where-Object {$_.Installed -eq $true}

        if ($IIS -ne $null)
        {
            Write-Verbose -Message 'IIS is already installed.'
        }
        else
        {
            Install-WindowsFeature -Name web-server -IncludeManagementTools | Out-Null
            Write-Information -MessageData 'Installed Webserver IIS.'
        }
        #endregion

        #region Check if DNS is installed - if not: Make it so!

        $DNS = Get-WindowsFeature -Name dns  | Where-Object {$_.Installed -eq $true}

        if ($DNS -ne $null)
        {
            Write-Verbose -Message 'DNS is already installed.'
        }
        else
        {
            Install-WindowsFeature -Name dns -IncludeManagementTools | Out-Null
            Write-Information -MessageData 'Installed DNS-Server.'
        }
        #endregion

        #region Check if Zones are set up - if not: Make it so!

        $ZoneNCSI = 'msftncsi.com'
        $ZoneConnecttest = 'msftconnecttest.com'
        $Zones = Get-DnsServerZone | where-Object {$_.zonename -eq $ZoneNCSI -or $_.zonename -eq $ZoneConnecttest}

        if ($Zones.Count -eq 2)
        {
            Write-Verbose -Message "Zones $ZoneNCSI and $ZoneConnecttest already exist."
        }
        else
        {
            $zones = @($ZoneNCSI, $ZoneConnecttest)

            foreach ($zone in $zones)
            {
                Add-DnsServerPrimaryZone -Name $Zone -DynamicUpdate None -ZoneFile "$Zone.dns" | Out-Null
                Write-Information -MessageData "Created DNSZone $Zone."
            }

        }
        #endregion

        #region Setting up some Variables for the Process Block
        $wwwroot = "$env:HOMEDRIVE\inetpub\wwwroot"
        $Checkwwwroot = Test-Path -Path "$wwwroot"
        $NCSITXT = 'ncsi.txt'
        $CheckNCSITXT = Test-Path -Path "$wwwroot\$NCSITXT"
        $connecttestTXT = 'connecttest.txt'
        $CheckConnecttestTXT = Test-Path -Path "$wwwroot\$connecttestTXT"
        $CheckwwwNCSI = Get-DnsServerResourceRecord -Name www -ZoneName "$ZoneNCSI" -ErrorAction 'SilentlyContinue'
        $CheckdnsNCSI = Get-DnsServerResourceRecord -Name dns -ZoneName "$ZoneNCSI" -ErrorAction 'SilentlyContinue'
        $CheckwwwConnecttest = Get-DnsServerResourceRecord -Name www -ZoneName "$ZoneConnecttest" -ErrorAction 'SilentlyContinue'
        $CheckdnsConnecttest = Get-DnsServerResourceRecord -Name dns -ZoneName "$ZoneConnecttest" -ErrorAction 'SilentlyContinue'
        $HostIP = (Get-NetIPConfiguration | Where-Object {$_.IPv4DefaultGateway -ne "$null" -and $_.NetAdapter.Status -ne "Disconnected"}).IPv4Address.IPAddress
        $splitIP = $HostIP.Split('.')
        $splitIP[2] = 255
        $splitIP[3] = 255
        $dnsIP = ($splitIP -join '.')
        $Interface = (Get-NetIPAddress -IPAddress $HostIP).InterfaceAlias
        $CheckPrefDNS = (Get-DnsClientServerAddress -AddressFamily IPv4 -InterfaceAlias $Interface).ServerAddresses
        $CheckDefGateway = (Get-NetIPConfiguration).IPv4DefaultGateway.NextHop
        #endregion
    }

    PROCESS
    {
        #region Check if inetpub\wwwroot is present - if not: Make it so!

        if ($Checkwwwroot -eq $true)
        {
            Write-Verbose -Message "Folder $wwwroot already exists."
        }
        else
        {
            New-Item -Path "$wwwroot" -ItemType Directory | Out-Null
            Write-Information -MessageData "Created $wwwroot."
        }
        #endregion

        #region Creating the ncsi-files in wwwroot

        if ($CheckNCSITXT -eq $true)
        {
            Write-Verbose -Message "File $NCSITXT already exists."
        }
        else
        {
            New-Item -Path "$wwwroot" -ItemType File -Name $ncsiTXT -Value 'Microsoft NCSI' | Out-Null
            Write-Information -MessageData "Created file $wwwroot\$NCSITXT."
        }

        if ($CheckConnecttestTXT -eq $true)
        {
            Write-Verbose -Message "File $connecttestTXT already exists."
        }
        else
        {
            New-Item -Path "$wwwroot" -ItemType File -Name $connecttestTXT -Value 'Microsoft Connect Test' | Out-Null
            Write-Information -MessageData "Created file $wwwroot\$connecttestTXT."
        }
        #endregion


        #region Create ResourceRecords, split HostIP to modify the last two octets for dns-record

        if ($CheckwwwNCSI -ne $null)
        {
            Write-Verbose -Message "Host(A) www already exists in $ZoneNCSI."
        }
        else
        {
            Add-DnsServerResourceRecordA -ZoneName "$ZoneNCSI" -Name www -IPv4Address $HostIP
            Write-Information -MessageData "Created Host(A) www in $ZoneNCSI with IP $HostIP."
        }

        if ($CheckdnsNCSI -ne $null)
        {
            Write-Verbose -Message "Host(A) dns already exists in $ZoneNCSI."
        }
        else
        {
            Add-DnsServerResourceRecordA -ZoneName "$ZoneNCSI" -Name dns -IPv4Address $dnsIP
            Write-Information -MessageData "Created Host(A) dns in $ZoneNCSI with IP $dnsIP."
        }

        if ($CheckwwwConnecttest -ne $null)
        {
            Write-Verbose -Message "Host(A) www already exists in $ZoneConnecttest."
        }
        else
        {
            Add-DnsServerResourceRecordA -ZoneName "$ZoneConnecttest" -Name www -IPv4Address $HostIP
            Write-Information -MessageData "Created Host(A) www in $ZoneConnecttest with IP $HostIP."
        }

        if ($CheckdnsConnecttest -ne $null)
        {
            Write-Verbose -Message "Host(A) dns already exists in $ZoneConnecttest."
        }
        else
        {
            Add-DnsServerResourceRecordA -ZoneName "$ZoneConnecttest" -Name dns -IPv4Address $dnsIP
            Write-Information -MessageData "Created Host(A) dns in $ZoneConnecttest with IP $dnsIP."
        }
        #endregion
    }

    END
    {
        #region Set HostIP as prefered DNS-Server

        if ($CheckPrefDNS -eq $HostIP)
        {
            Write-Verbose -Message "Preferred DNS-Server is $HostIP - localhost."
        }
        else
        {
            Set-DnsClientServerAddress -InterfaceAlias $Interface -ServerAddresses $HostIP | Out-Null
            Write-Information -MessageData "Preferred DNS-Server has been changed to $HostIP - localhost."
        }

        if ($CheckDefGateway -eq $null)
        {
            New-NetRoute -InterfaceAlias $Interface -DestinationPrefix '0.0.0.0/0' -NextHop $HostIP -Confirm:$false | Out-Null
            Write-Information -MessageData "Set default route to $HostIP - localhost."

        }

        # region Disable and enable NetworkAdapter (ugly, but less risky than Restart-Service NLASvc b/c of its dependencies...)
        Disable-NetAdapter -Name $Interface -Confirm:$false
        Enable-NetAdapter -Name $Interface -Confirm:$false
        Write-Information -MessageData 'THE MACHINE NOW THINKS IT HAS A REAL INTERNET CONNECTION.'
    }
}
