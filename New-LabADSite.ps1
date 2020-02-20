function New-LabADSiteSubnet {
    <#
    .SYNOPSIS
    Creates csv-imported Active Directory sites and subnets in a virtual lab-environment.
    THIS CODE IS NOT FOR PRODUCTION USE!

    .DESCRIPTION
    New-LabADSiteSubnet relies on an csv-file containing columns for sites and subnets.
    It imports the sites and subnets. Nothing fancy.

    .PARAMETER CSVPath
    The Path to the csv-file you want to import.

    .EXAMPLE
        Dot source it or load it another way.
        New-LabADSiteSubnet -CSVPath "c:\ad_sites_subnets.csv"

    .LINK
        Online version: https://github.com/JaekelEDV/PSLabHelpers/blob/master/New-LabADSite.ps1

    .NOTES
    New-LabADSiteSubnet can also put all the sites in the DEFAULTIPSITELINK.
    If this is not wanted in your lab - just comment it out.

    FileName:   New-LabADSiteSubnet.ps1
    Author:     Oliver Jaekel
    EMail:      oj@jaekel-edv.de
    www:        github.com/JaekelEDV
    Twitter:    @JaekelEDV
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateScript( {Test-Path -Path $_ })]
        [string] $CSVPath
    )

    #Requires –Modules ActiveDirectory

    $InformationPreference = 'Continue'
    $CSV = Import-Csv -Path $CSVPath

    foreach ($site in $CSV){
        if (Get-ADReplicationSite -Filter * -Properties Name |
            Where-Object {$_.name -eq $site.site}) {
            Write-Information "Site $($site.site) already exists."
        }

        else {
            New-ADReplicationSite -Name $site.site
            Write-Information "Site $($site.site) is created."
        }
    }

    foreach ($subnet in $CSV) {
        if (Get-ADReplicationSubnet -Filter * -Properties Name |
            Where-Object {$_.name -eq $subnet.subnet}) {
            Write-Information "Subnet $($subnet.subnet) already exists."
        }

        else {
            New-ADReplicationSubnet -Name $subnet.subnet -Site $subnet.site
            Write-Information "Subnet $($subnet.subnet) is created."
        }
    }

    #Optional: putting all sites in DEFAULTIPSITELINK - don't like it, drop it.
    $AllSites = (Get-ADReplicationSite -Filter *).name
    Set-ADReplicationSiteLink -Identity DEFAULTIPSITELINK -SitesIncluded @{add = $AllSites}
}
