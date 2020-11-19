function Test-IntSvcGuest {
    <#
    .SYNOPSIS
        Test-IntSvcGuest checks if the Hyper-V Guest Integration Service is enabled.

    .DESCRIPTION
        Test-IntSvcGuest checks if the Hyper-V Guest Integration Service is enabled.
        The Guest Integration Services are a prequisite if you'd like to
        copy files from the Hyper-V-Host to a VM without using a network stack, e.g.
        with Copy-VMFile.
        https://docs.microsoft.com/en-us/powershell/module/hyper-v/copy-vmfile?view=win10-ps
        Requires elevation; must be run in a PowerShell session as an administrator.

    .PARAMETER VM
        The name of the VM(s) you want to check.

    .EXAMPLE
        Dot source it or load it another way.
        C:\PS>. .\Test-IntSvcGuest
        C:\PS>Test-IntSvcGuest -VM 'vMACHINE'
        This will check one VM.

    .EXAMPLE
        Dot source it or load it another way.
        C:\PS>. .\Test-IntSvcGuest
        C:\PS>Test-IntSvcGuest -VM 'vMACHINE1','vMACHINE2'
        This will check multiple VMs separated by comma.

    .EXAMPLE
        Dot source it or load it another way.
        C:\PS>. .\Test-IntSvcGuest
        C:\PS>$Computers = Get-Content -Path computer.txt
        C:\PS>$Computers | Test-IntSvcGuest
        This will allow you to pipe a list of VMNames from a .txt-file.

    .INPUTS
        Test-IntSvcGuest accepts input from the pipe, e.g. from a txt.-file.

    .OUTPUTS
        Test-IntSvcGuest
        System.String. Test-IntSvcGuest returns a string from Write-Host.

    .LINK
        Online version: https://github.com/JaekelEDV/

    .NOTES
        File Name: Test-IntSvcGuest.ps1
        Author: Oliver Jaekel | oj@jaekel-edv.de | @JaekelEDV | https://github.com/JaekelEDV
    #>
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline=$true)]
        [string[]]$VMName
    )
    #Requires -RunAsAdministrator
    begin {#not needed
    }
    process {
        ForEach ($VM in $VMName) {
            $IntSvc = Get-VMIntegrationService -VMName $VM |
            Where-Object {
                $_.Name -eq 'Gastdienstschnittstelle' -or
                $_.Name -eq 'Guest Service Interface'
            }

            if ($IntSvc.Enabled -eq $false) {
                Enable-VMIntegrationService -VMName $VM -Name $IntSvc.Name -ErrorAction 'Stop'
                Write-Host  "Guest Integration Services now enabled on $VM." -ForegroundColor Yellow
            }
            else {
                Write-Host "Guest Integration Services already enabled on $VM." -ForegroundColor Green
            }
        }
    }#process end
    end {#not needed
    }
}
