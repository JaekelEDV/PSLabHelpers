<#
.SYNOPSIS
    New-LabVM quickly creates VM on Hyper-V for Lab Environments
.DESCRIPTION
    This Script creates a Windows Server 2016 or Windows Server 2022 Generation 2 VM
    with differencing disk based on *existing* Master-VHDx.
    It connects to an existing external vSwitch to activate the License.
    Automatic checkpoints are disabled.
    The VM starts automatically.
    Be sure to adjust paths in the variables according to your environment -
    this script relies heavily on personal surroundings.
.PARAMETER OSType
    Choice between Server 2016 or Server 2022.
    All depending on existing Master-VHDx.
.PARAMETER VMName
    Sets the Name of the VM to create.
.EXAMPLE
    New-LabVM -VMName [Value] -OSType [Value]
.NOTES
    Author: Oliver Jäkel | oj@jaekel-edv.de | @JaekelEDV | https://github.com/jaekeledv
#>

[CmdletBinding()]
param (
    [Parameter(
        Mandatory = $true,
        Position=0
    )]
    [string]$VMName,

    [Parameter(
        Mandatory = $true,
        Position=1
    )]
    [ValidateSet('Server2016', 'Server2022')]
    [string]$OSType
)

$VMPath = "D:\$VMName"
$VHDXPath = "D:\$VMName\$VMName.vhdx"
$VHDXSize = 127GB
$MasterVHDXServer2016 = "D:\MASTER\master_2016.vhdx"
$MasterVHDXServer2022 = "D:\MASTER\master_2022.vhdx"

$WarningPreference = 'Stop'

#region Check if chosen Master.vhdx exists

if ($OSType -eq 'Server2016') {
    if (Test-Path -Path $MasterVHDXServer2016) {
        Write-Verbose -Message 'Master_2016 found.'
    }
    else {
        Write-Warning -Message 'Cannot find master_2016.vhdx. Check filename or create it.'
    }
}

if ($OSType -eq 'Server2022') {
    if (Test-Path -Path $MasterVHDXServer2022) {
        Write-Verbose -Message 'Master_2022 found.'
    }
    else {
        Write-Warning -Message 'Cannot find master_2022.vhdx. Check filename or create it.'
    }
}
#endregion

#region Create VM
$VMParams = @{
    Name               = $VMName
    MemoryStartupBytes = 1024MB
    Generation         = 2
    NoVHD              = $true
    Path               = $VMPath
}

New-VM @VMParams
Write-Verbose -Message "Created VM $VMName in $VMPath."
#endregion

#region Set VM
$VMConfig = @{
    Name               = $VMName
    DynamicMemory      = $true
    ProcessorCount     = 4
    MemoryMaximumBytes = 4GB
    CheckpointType     = "Disabled"
}

Set-VM @VMConfig
Write-Verbose -Message "Setting VM $VMName as desired."
#endregion

#region Create differencing Disks according to OSType-Selection
switch ($OSType) {
    'Server2016' {
        $2016VM = @{
            Differencing = $true
            ParentPath   = $MasterVHDXServer2016
            Path         = $VHDXPath
            SizeBytes    = $VHDXSize
        }
        New-VHD @2016VM
        Write-Verbose -Message "Created differencing disk for $VMName."
    }
    'Server2022' {
        $2022VM = @{
            Differencing = $true
            ParentPath   = $MasterVHDXServer2022
            Path         = $VHDXPath
            SizeBytes    = $VHDXSize
        }
        New-VHD @2022VM
        Write-Verbose -Message "Created differencing disk for $VMName."
    }
}
#endregion

#region Attach Disk to VM
$VMHDD = @{
    VMName           = $VMName
    ControllerType   = "SCSI"
    ControllerNumber = "0"
    Path             = $VHDXPath
}

Add-VMHardDiskDrive @VMHDD
#endregion

#region Set Bootorder
$VMDisk = Get-VMHardDiskDrive -VMName $VMName
Set-VMFirmware -VMName $VMName -FirstBootDevice $VMDisk
#endregion

#region Determine external vSwitch and connect vNIC to it
$VMSwitch = (Get-VMSwitch -SwitchType External).Name
Get-VMNetworkAdapter -VMName $VMName |
Connect-VMNetworkAdapter -SwitchName $VMSwitch
#endregion

#region Start-VM
Start-VM -Name $VMName
#endregion
