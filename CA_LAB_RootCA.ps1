<#
      .SYNOPSIS
      Script to install and configure a standalone RootCA for Lab-Environments
      .DESCRIPTION
      This Script sets up a standalone RootCA. It's main purpose is to save time when building Labs in the classes I teach.
      ###It's not meant for production!###
      First, it creates a CAPolicy.inf file. Then it deletes all default CDP and AIA and configures new ones.
      It turns on auditing and copys (It's a Lab!!!, so obviously no real offline RootCA...) the crt and crl to an edge webserver.
      .NOTES
      Author: Oliver Jäkel | oj@jaekel-edv.de | @JaekelEDV
#>

#I recommend to not comment this out - you get customized verbose-messages and avoid a lot of clutter.
$VerbosePreference = 'Continue'

#Defining Filename and Path for CAPolicy.inf
$CAPolicyPath = "$env:systemroot"
$CAPolicyFileName = 'CAPolicy.inf'

#$VerboseOn
Write-Verbose -Message "Creating $CAPolicyFileName in $CAPolicyPath..."
#$VerboseOff

#Checking if file CAPolicy.inf already exist
if
((Test-Path -Path $env:systemroot/$CAPolicyFileName) -eq $true)
{
    Write-Host  "Attention! File $CAPolicyFileName already exists in $CAPolicyPath. Script will stop now!" -ForegroundColor Red
    Exit
}

#Defining the Content of the CAPolicy.inf for the RootCA using a here-string.
[string]$string = '$Windows'
$CAPolicyContent = @"
[Version]
Signature="$string NT$"
[Certsrv_Server]
RenewalKeyLength=4096
RenewalValidityPeriod=Years
RenewalValidityPeriodUnits=30
CRLPeriod=Months
CRLPeriodUnits=6
"@

#Creating the File
[void] (New-Item -ItemType File -Path $CAPolicyPath -Name $CAPolicyFileName -Value $CAPolicyContent -Verbose:$False)

#Adding the Feature
Write-Verbose -Message 'Installing the CA-Feature...'
[void] (Add-WindowsFeature ADCS-Cert-Authority -IncludeManagementTools -Verbose:$False)

#Putting the wanted parameters in a hashtable for better readability and flexibility - then do the config
$params = @{
    CAType              = 'StandaloneRootCA'
    CACommonName        = 'RootCA'
    KeyLength           = '4096'
    HashAlgorithm       = 'SHA256'
    CryptoProviderName  = "RSA#Microsoft Software Key Storage Provider"
    ValidityPeriod      = 'Years'
    ValidityPeriodUnits = '20'
}
Write-Verbose -Message 'Configuring the RootCA...'
[void] (Install-ADCSCertificationAuthority @params -Force -Verbose:$False)

#Deleting the default CDP
Write-Verbose -Message 'Removing the default CDA...'
$CRLs = Get-CACrlDistributionPoint -Verbose:$False
foreach ($CRL in $CRLs)
{
    [void] (Remove-CACrlDistributionPoint $CRL.uri -Force -Verbose:$False)
}

#Adding the new CDP
$CAName = 'RootCA'
$CRLDist = "http://edge.test.local/CRLDist"
$CRLLocalPath = "$Env:SystemRoot\System32\CertSrv\CertEnroll"
$CRLFileName = "$CAName%8%9.crl" #%8:<CRLNameSuffix, %9:<DeltaCRLAllowed>

Write-Verbose -Message "Setting new CDA to $CRLDist..."
[void] (Add-CACRLDistributionPoint -Uri $CRLLocalPath\$CRLFileName -PublishToServer -PublishDeltaToServer -Force -Verbose:$False)
[void] (Add-CACRLDistributionPoint -Uri $CRLDist/$CRLFileName -AddToCertificateCDP -AddToFreshestCrl -Force -Verbose:$False)

#Deleting the default AIA
Write-Verbose -Message 'Removing the default AIA...'

[void] (Get-CAAuthorityInformationAccess -Verbose:$False |
    Where-Object {$_.Uri -like '*ldap*' -or $_.Uri -like '*http*' -or $_.Uri -like '*file*'} |
        Remove-CAAuthorityInformationAccess -Force -Verbose:$False)

#Adding the new AIA
$CRTFileName = "$CAName%4.crt" #%4:<CertificateName>

Write-Verbose -Message 'Setting new AIA...'
[void] (Add-CAAuthorityInformationAccess -AddToCertificateAIA $CRLDist/$CRTFileName -Force -Verbose:$False)

#Postconfig
Write-Verbose -Message 'Doing some config stuff with certutil...'

[void] (certutil.exe –setreg CA\CRLPeriodUnits '20')
[void] (certutil.exe –setreg CA\CRLPeriod 'Years')
[void] (certutil.exe –setreg CA\ValidityPeriodUnits '10') #This defines the max Validity of SubCA-Certificates!
[void] (certutil.exe –setreg CA\ValidityPeriod 'Years')
[void] (certutil.exe -setreg CA\AuditFilter '127') #Audit everything

#Enable the object access auditing - ATTENTION: This is the syntax for a localized de-DE OS!
Write-Verbose -Message 'Enabling total CA-auditing with Auditfilter 127...'

[void] (Auditpol /set /subcategory:'Zertifizierungsdienste' /failure:enable /success:enable)

#Restart the CA-Service to set the changes
Write-Verbose -Message 'Restarting certsvc...'

$svc = (Get-Service -Name certsvc)
[void] (Restart-Service  $svc -Verbose:$False)
$svc.WaitForStatus('Running') #Halt the script until the service is up again

#Publish the CRL
Write-Verbose -Message "Publishing the CRL to $CRLLocalPath"

[void] (certutil.exe -crl)

#copy crl to CRLDist
$Dest = "\\edge.test.local\CRLDist\"
Write-Verbose -Message "Copying the CRL and the CRT to $Dest..."
[void] (Copy-Item -Path "$CRLLocalPath\*.crl" -Destination $Dest -Verbose:$False)

#copy crt to CRLDist
[void] (Copy-Item -Path "$CRLLocalPath\*.crt" -Destination $Dest -Verbose:$False)

Write-Host '=============================================' -ForegroundColor Green
Write-Host 'CONGRATS! YOU HAVE A READY-TO-USE ROOTCA NOW!' -ForegroundColor Green
Write-Host '=============================================' -ForegroundColor Green
