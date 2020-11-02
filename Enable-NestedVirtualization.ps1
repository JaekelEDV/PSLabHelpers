<#
.SYNOPSIS
    Enable-NestedVirtualization configures virtual machines to support nested virtualization.
.DESCRIPTION
    Enable-NestedVirtualization configures all needed prerequisites if you want to install
    the Hyper-V-Role inside a virtual machine. It
    - shuts down the VM
    - enables virtualization extensions of the VMProcessor
    - disables dynamic memory
    - allows MAC-address spoofing on the virtual NIC
    - restarts the VM
.EXAMPLE
    PS C:\> Enable-NestedVirtualizaion -VMName vm1,vm2
    This command configures the prerequisites for nested virtualization in all given virtual machines.
.NOTES
    FileName:   Enable-NestedVirtualization.ps1
    Author:     Oliver Jaekel
    www:        github.com/JaekelEDV
    Twitter:    @JaekelEDV
#>
[CmdletBinding(SupportsShouldProcess)]
param (
    [Parameter(
        Mandatory = $True,
        ValueFromPipeline=$true)]
    [string[]]$VMName
)

foreach ($VM in $VMName){

    try {
        $VMState = (Get-VM -Name $VMName).State

        if ($VMState -eq "Running") {
            Write-Host "Stopping VMs." -ForegroundColor Yellow
            Stop-VM -Name $VMName
        }
    }

    catch {
        Write-Warning $_.Exception.Message
        throw "That's all folks, something went terribly wrong. Cannot configure $VM."
    }

    try {
        $VMProc = (Get-VMProcessor -VMName $VM).ExposeVirtualizationExtensions
        $VMMem = (Get-VMMemory -VMName $VM).DynamicMemoryEnabled
        $VMNIC = (Get-VMNetworkAdapter -VMName $VM).MacAddressSpoofing

        if ($VMProc -eq $false) {
            Write-Host "Setting ExposeVirtualizationExtensions on $VM to 'true'." -ForegroundColor Yellow
            Set-VMProcessor -VMName $VM -ExposeVirtualizationExtensions $true
        }
        else {
            Write-Host "Setting ExposeVirtualizationExtensions on $VM is already 'true'." -ForegroundColor Green
        }

        if ($VMMem -eq $true) {
            Write-Host "Setting DynamicMemory on $VM to 'Off'." -ForegroundColor Yellow
            Set-VMMemory -VMName $VM -DynamicMemoryEnabled $false
        }
        else {
            Write-Host "Setting DynamicMemory on $VM is already 'false'." -ForegroundColor Green
        }

        if ($VMNIC -eq "Off") {
            Write-Host "Setting MacAddressSpoofing on $VM to 'On'." -ForegroundColor Yellow
            Set-VMNetworkAdapter -VMName $VM -MacAddressSpoofing "On"
        }
        else {
            Write-Host "Setting MacAddressSpoofing on $VM is already 'On'." -ForegroundColor Green
        }

    }
    catch {
        Write-Warning $_.Exception.Message
        throw "That's all folks, something went terribly wrong. Cannot configure $VM."
    }
}

foreach ($VM in $VMName){
    ""
    Write-Host "Starting $VM..." -ForegroundColor Yellow
    Start-VM -Name $VM

    do {
        Write-Host "[+]$VM not ready. Waiting..." -ForegroundColor Yellow
        $Heartbeat = (Get-VM -Name $VM).HeartBeat
        Start-Sleep -Seconds 3
    }

    until ($Heartbeat -eq 'OkApplicationsUnknown'-or $Heartbeat -eq 'OkApplicationsHealthy')
    ""
    Write-Host "[+]$VM is ready." -ForegroundColor Green
    Write-Host "VM status is $Heartbeat." -ForegroundColor Green
}
