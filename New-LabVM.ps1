<#
.SYNOPSIS
    Function New-LabVM quickly creates VM on Hyper-V for Lab Environments
.DESCRIPTION
    This Script creates a Windows Server 2016, Windows Server 2012 R2 or Windows 10 Generation 2 VM
    with differencing disk based on existing Master-VHDx you have to create before executing this one.
    Be sure to adjust paths in the "Parameter Section Region" according to your environment.
    It connects to an existing external vSwitch to activate the License.
    The VM starts automatically.
.PARAMETER OSType
    Choice between Server2012R2, Server 2016, Server 2016_core or Windows10. All depending on existing Master-VHDx.
.PARAMETER VMName
    Sets the Name of the VM to create.
.EXAMPLE
    Execute New-LabVM.ps1 directly from Shell with dot sourcing
    . .\New-LabVM.ps1
    New-LabVM -VMName Value -OSType Value
    You might consider putting the function in your PS-Profile.
.NOTES
    Author: Oliver Jäkel | oj@jaekel-edv.de | @JaekelEDV
#>
#region Parameter Section
Function New-LabVM
{
    [CmdletBinding()]
    param (
        $WarningPreference = 'Stop',
        [Parameter(Mandatory = $true)][ValidateSet('Server2012R2', 'Server2016', 'Server2016_core', 'Windows10')][string]$OSType,
        [Parameter(Mandatory = $true)][string] $VMName)

    [string] $VMPath = "d:\$VMName"
    [string] $VHDXPath = "d:\$VMName\$VMName.vhdx"
    [long]   $VHDXSize = 136365211648
    [string] $MasterVHDXServer2012R2 = 'd:\MASTER\master_2012R2.vhdx'
    [string] $MasterVHDXClient = 'd:\MASTER\master_win10.vhdx'
    [string] $MasterVHDXServer2016 = 'd:\MASTER\master_2016.vhdx'
    [string] $MasterVHDXServer2016Core = 'd:\MASTER\master_2016_core.vhdx'
    #endregion

    #region Import Hyper-V Module
    $LoadedModules = (Get-Module).Name
    if ($LoadedModules -notcontains 'Hyper-V')
    {Import-Module Hyper-V
    }
    else
    {write-host 'Hyper-V Module already loaded' -ForegroundColor Yellow
    }
    #endregion
    #region Check if chosen Master.vhdx exists
    if ($OSType -eq 'Server2012R2')
    {if (Test-Path -Path $MasterVHDXServer2012R2)
        {Write-Verbose -Message 'Master_2012R2 found.'
        }
        else
        {Write-Warning -Message 'Cannot find master_2012R2.vhdx. Check filename or create it.'
        }
    }

    if ($OSType -eq 'Server2016')
    {if (Test-Path -Path $MasterVHDXServer2016)
        {Write-Verbose -Message 'Master_2016 found.'
        }
        else
        {Write-Warning -Message 'Cannot find master_2016.vhdx. Check filename or create it.'
        }
    }

    if ($OSType -eq 'Server2016_core')
    {if (Test-Path -Path $MasterVHDXServer2016core)
        {Write-Verbose -Message 'Master_2016_core found.'
        }
        else
        {Write-Warning -Message 'Cannot find master_2016_core.vhdx. Check filename or create it.'
        }
    }

    if ($OSType -eq 'Windows10')
    {if (Test-Path -Path $MasterVHDXClient)
        {Write-Verbose -Message 'Master_Win10 found.'
        }
        else
        {Write-Warning -Message 'Cannot find master_Win10.vhdx. Check filename or create it.'
        }
    }
    #endregion

    #region Create VM
    New-VM -Name $VMName -MemoryStartupBytes 1024MB -Generation 2 -NoVHD -Path $VMPath
    #endregion

    #region Set VM
    Set-VM -Name $VMName -DynamicMemory -ProcessorCount 4 -MemoryMaximumBytes 4GB

    # following is not supported for gen2
    # Set-VMBios -VMName $VMName -EnableNumLock
    #endregion

    #region Create differencing Disks according to OSType-Selection
    switch ($OSType)
    {
        'Server2012R2'
        {New-VHD -Differencing -ParentPath $MasterVHDXServer2012R2 -Path $VHDXPath -SizeBytes $VHDXSize
        }
        'Server2016'
        {New-VHD -Differencing -ParentPath $MasterVHDXServer2016 -Path $VHDXPath -SizeBytes $VHDXSize
        }
        'Windows10'
        {New-VHD -Differencing -ParentPath $MasterVHDXClient -Path $VHDXPath -SizeBytes $VHDXSize
        }
        'Server2016_core'
        {New-VHD -Differencing -ParentPath $MasterVHDXServer2016Core -Path $VHDXPath -SizeBytes $VHDXSize
        }
    }
    #endregion

    #region Attach Disk to VM
    Add-VMHardDiskDrive -VMName $VMName -ControllerType SCSI -ControllerNumber 0 -Path $VHDXPath
    #endregion

    #region Set Bootorder
    Set-VMFirmware -VMname $VMName -FirstBootDevice (Get-VMHardDiskDrive -VMName $vmName)[0]
    #endregion

    #region Determine external vSwitch and connect vNIC to it
    $VMSwitch = (Get-VMSwitch -SwitchType External).Name
    Get-VMNetworkAdapter -VMName $VMName | Connect-VMNetworkAdapter -SwitchName $VMSwitch
    #endregion

    #region Disable automatic Checkpoint
    Set-VM -Name $VMName -AutomaticCheckpointsEnabled $false
    #endregion

    #region Start-VM
    Start-VM -Name $VMName
    #endregion
}
