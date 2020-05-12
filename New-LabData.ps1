<#
.SYNOPSIS
    This script creates a folder and some subfolders with randomly named example txt-files for Lab environments.
.DESCRIPTION
    This is a quick and dirty solution - same timestamps, same size when content within files.
    You'll find plenty of better scripts, but this is exactly what I needed for a small project.
    The foldernames are hardcoded, you can adjust them.
    The filenames are generated randomly with the .NET class System.IO.File, the file-extensions are then
    all changed to *.txt. Originally they are created with different filesizes, but this changes when you'll
    make use of the Set-Content cmdlet (which you're free to comment out).
    The script uses a REST-API which downloads some Lorem Ipsum content (which obviously isn't needed, too).
    As said, when using it this way, you'll lose the different file-sizes which might be of interest.
.EXAMPLE
    Just run it: PS C:\> .\New-LabData.ps1. There are no parameters.
.NOTES
    File Name: New-LabData.ps1
    Author: Oliver Jaekel | oj@jaekel-edv.de | @JaekelEDV | https://github.com/JaekelEDV
#>
[CmdletBinding()]
param ()

#region Create Rootfolder for LabData.
$RootFolder = 'C:\LabData'
if (-not (Test-Path -LiteralPath $RootFolder)) {

    try {
        New-Item -Path $RootFolder -ItemType 'Directory' -ErrorAction 'Stop' | Out-Null
        Write-Verbose "Created directory $RootFolder."
    }
    catch {
        Write-Error "Unable to create directory '$RootFolder'. Error: $_" -ErrorAction 'Stop'
    }
}

else {
    Write-Verbose "Directory $RootFolder already exists."
}
#endregion

#region Create subfolders under RootFolder
#Feel free to alter this section and write your preferred names to the variable.
$Subfolder = @('logs','data1','data2','data3','misc','secret')

foreach($Folder in $Subfolder) {
    New-Item -Path $RootFolder -Name $Folder -ItemType 'Directory' | Out-Null
}
$Subfolders = $Subfolder -join ', '
Write-Verbose "Created subfolders $Subfolders under $RootFolder"
#endregion

#region Download LoremIpsum and create content-file
#If you're ok with empty files, you don't need this region.
Invoke-WebRequest -Uri "https://loripsum.net/api/5/long/plaintext" |
New-Item -Path $RootFolder -Name 'LoremIpsum.txt' -ItemType 'File' | Out-Null
$Content = Get-Content -Path "$RootFolder\LoremIpsum.txt"
Write-Verbose "Downloaded Lorem Ipsum and created content-txt-file."
#endregion

#region Create random files
#function New-EmptyFile by @ShayLevy: https://www.powershellmagazine.com/2012/11/22/pstip-create-a-file-of-the-specified-size/
function New-EmptyFile {
    param([string]$FilePath,[double]$Size)
    $file = [System.IO.File]::Create($FilePath)
    $file.SetLength($Size)
    $file.Close()
}

do {
    $filename = [System.IO.Path]::GetRandomFileName()
    $Subfolder = (Get-ChildItem -Directory -Path $RootFolder\*).Name

    foreach($Folder in $Subfolder) {
        New-EmptyFile -FilePath "$RootFolder\$Folder\$filename" -Size (Get-Random -Minimum 1024 -Maximum 819200)
    }
}
#Please change the value (here: 50) if you'll need more files.
until ((Get-ChildItem -File -Recurse -Path $RootFolder).count -ge 50)
Write-Verbose "Created random files under $RootFolder\$Folder."
#endregion

#region Rename random file-extension to *.txt
Get-ChildItem -File -Recurse -Path $RootFolder |
Rename-Item -NewName { [io.path]::ChangeExtension($_.name, "txt") }
Write-Verbose "Renamed random file-extension to *.txt"
#endregion

#region Set-Content Lorem Ipsum to all txt-files
#Attention: this will result in same filesize for all files which perhaps is not desired.
Set-Content -Path $RootFolder\*\* -Filter *.txt  -Value "$Content"
Write-Verbose "Set content Lorem Ipsum to all txt-files"
#endregion
$CountFiles = (Get-ChildItem -File -Recurse -Path $RootFolder).count
Write-Host "READY! Created $CountFiles test-files under $RootFolder." -ForegroundColor Cyan
