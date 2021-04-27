<#
.SYNOPSIS
    New-LabVM quickly creates VM on Hyper-V for Lab Environments
.DESCRIPTION
    This Script creates a Windows Server 2012R2, Windows Server 2016 or Windows Server 2019 Generation 2 VM
    with differencing disk based on *existing* Master-VHDx.
    It connects to an existing external vSwitch to activate the License.
    Automatic checkpoints are disabled.
    The VM starts automatically.
    Be sure to adjust paths in the variables according to your environment -
    this script relies heavily on personal surroundings.
.PARAMETER OSType
    Choice between Server2012R2, Server 2016 or Server 2019.
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
    [ValidateSet('Server2012R2', 'Server2016', 'Server2019')]
    [string]$OSType
)

<#$VMPath = 'C:\VMs\$VMName'
$VHDXPath = 'C:\VMs\$VMName\$VMName.vhdx'
$VHDXSize = 127GB
$MasterVHDXServer2012R2 = 'C:\VMs\MASTER\master_2012R2.vhdx'
$MasterVHDXServer2016 = 'C:\VMs\MASTER\master_2016.vhdx'
$MasterVHDXServer2019 = 'C:\VMs\MASTER\master_2019.vhdx'
#>
$VMPath = "D:\$VMName"
$VHDXPath = "D:\$VMName\$VMName.vhdx"
$VHDXSize = 127GB
$MasterVHDXServer2012R2 = "D:\MASTER\master_2012R2.vhdx"
$MasterVHDXServer2016 = "D:\MASTER\master_2016.vhdx"
$MasterVHDXServer2016Core = "D:\MASTER\master_2019.vhdx"

$WarningPreference = 'Stop'

#region Check if chosen Master.vhdx exists
if ($OSType -eq 'Server2012R2') {
    if (Test-Path -Path $MasterVHDXServer2012R2) {
        Write-Verbose -Message 'Master_2012R2 found.'
    }
    else {
        Write-Warning -Message 'Cannot find master_2012R2.vhdx. Check filename or create it.'
    }
}

if ($OSType -eq 'Server2016') {
    if (Test-Path -Path $MasterVHDXServer2016) {
        Write-Verbose -Message 'Master_2016 found.'
    }
    else {
        Write-Warning -Message 'Cannot find master_2016.vhdx. Check filename or create it.'
    }
}

if ($OSType -eq 'Server2019') {
    if (Test-Path -Path $MasterVHDXServer2016core) {
        Write-Verbose -Message 'Master_2019 found.'
    }
    else {
        Write-Warning -Message 'Cannot find master_2019.vhdx. Check filename or create it.'
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
#endregion

#region Create differencing Disks according to OSType-Selection
switch ($OSType) {
    'Server2012R2' {
        $2012R2VM = @{
            Differencing = $true
            ParentPath   = $MasterVHDXServer2012R2
            Path         = $VHDXPath
            SizeBytes    = $VHDXSize
        }
        New-VHD @2012R2VM
    }
    'Server2016' {
        $2016VM = @{
            Differencing = $true
            ParentPath   = $MasterVHDXServer2016
            Path         = $VHDXPath
            SizeBytes    = $VHDXSize
        }
        New-VHD @2016VM
    }
    'Server2019' {
        $2019VM = @{
            Differencing = $true
            ParentPath   = $MasterVHDXServer2019
            Path         = $VHDXPath
            SizeBytes    = $VHDXSize
        }
        New-VHD @2019VM
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
