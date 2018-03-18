<#
.SYNOPSIS
    Function New-LabCert creates a selfsigned computercertificate for lab environments
.DESCRIPTION
    This script creates a selfsigned computercertificate for lab environments. It is stored in cert:\localmachine\my
    and from there it is exported as a pfx-file to c:\. This file then gets imported in 'Trusted Roots' to make it trustworthy.
    Finally some cleanup is performed, e.g. the pfx-file will be deleted.
    Please consider to run it with the -verbose parameter to receive some informative output.
.PARAMETER DNSName
    This is the only but mandatory parameter. Please enter the DNSHostname of the machine you want this certificate for.
    This will become the CN of the certficate
.EXAMPLE
    Execute New-LabCert.ps1 directly from shell with dot sourcing
    . .\New-LabCert.ps1
    New-LabCert -DNSName Value
.NOTES
    Author: Oliver Jäkel | oj@jaekel-edv.de | @JaekelEDV
#>

#requires -Version 3.0 -Modules PKI

#region Parameter Section
Function New-LabCert
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, HelpMessage = 'Enter DNSName of the Host')][string] $DNSName)
    [string] $certstorelocation = 'Cert:\LocalMachine\'
    #endregion

    #region Create the selfsigned Certificate

    New-SelfSignedCertificate -CertStoreLocation $certstorelocation\My -DnsName $DNSName
    Write-Verbose -Message "Creating Selfsigned Computer Certificate for $DNSName"
    #endregion

    #region Export the certificate to filesystem

    Set-Location -Path Cert:\LocalMachine\My
    $cert = Get-ChildItem -Path .\ | Where-Object -EQ -Property Subject -Value "cn=$DNSName"
    $thumbprint = ($cert).Thumbprint

    $pwd = ConvertTo-SecureString -String "Pa$$w0rd" -Force -AsPlainText
    Export-PfxCertificate -Cert $certstorelocation\My\$thumbprint -FilePath $env:HOMEDRIVE\$DNSName.pfx -Password $pwd
    Write-Verbose -Message "Export the Certificate to $env:HOMEDRIVE"
    #endregion

    #region Import the certificate to Trusted Root

    Import-PfxCertificate -FilePath $env:HOMEDRIVE\$DNSName.pfx -CertStoreLocation $certstorelocation\Root -Password $pwd
    Write-Verbose -Message 'Import the Certificate to Trusted Root'
    #endregion

    #region Cleanup

    Set-Location -Path $env:HOMEDRIVE
    Remove-Item -Path $env:HOMEDRIVE\$DNSName.pfx
    #endregion
}
