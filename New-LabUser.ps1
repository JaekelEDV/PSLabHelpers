<#
      .SYNOPSIS
      New-LabUser.ps1 creates User-Accounts and Groups for Lab Environments based on a csv-file.
      .DESCRIPTION
      This Script creates User-Accounts for a Lab based on a csv-file.
      Right now the script will look for the headers Name,SamAccountName,UPN,GivenName,Surname,DisplayName,EmailAddress and GroupName.
      Of course you might add others as well. Adjust the csv and the hashtable for New-ADUser accordingly.
      The users will get a Password which you might set in the parameter section below.
      The Script has two mandatory Parameters (see the parameters help section):
      You must point to your csv-file and you must specify a OU in which the users will be created. If this OU doesn't exist, the script will create it for you.
      You can simply pass a name, no need to type a distinguished name.

      .PARAMETER CSVPath
      Please enter the Path where your csv-file lives.

      .PARAMETER OU
      Please enter the Name of the OU where your new users shall live. There is no need of using the DistinguishedName - just write a name.

      .EXAMPLE
      New-LabUser -CSVPath .\lab_users.csv -OU Foo

      .NOTES
      Author: Oliver Jäkel | oj@jaekel-edv.de | @JaekelEDV
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true,
        HelpMessage="Enter just the name of the OU!")]
    [string] $CSVPath,
    [Parameter(Mandatory = $true,
        HelpMessage="Enter the path to the csv-file!!")]
    [string] $OU
)

#region Setting some variables and starting a transcript
$OU='Benutzer'
$csvpath = 'C:\lab_user.csv'

Start-Transcript -Path $env:userprofile\Desktop\LOG-NewLabUser.txt -IncludeInvocationHeader

$CSVUser = Import-Csv -LiteralPath $CSVPath
$Password = (ConvertTo-SecureString -String 'Pa$$w0rd' -AsPlainText -Force) #Change the Password here if you like.
$Domain = (Get-ADDomain).DistinguishedName
#endregion

#region Creating the OU from parameter $OU
Try {
    New-ADOrganizationalUnit -Name $OU -ProtectedFromAccidentalDeletion $false
}
Catch {
    $error[0]
}

$DestOU = (Get-ADOrganizationalUnit -Identity "ou=$OU,$Domain").DistinguishedName

Write-Host "Creating OU $DestOU..." -ForegroundColor Yellow
Write-Host ""
Write-Host "Creating Users..." -ForegroundColor Yellow
Write-Host ""
#endregion

#region Creating the users from csv
try{
    foreach ($user in $CSVUser) {
        $params = @{
            Name              = $user.Name
            Displayname       = "$($user.GivenName) $($user.Surname)"
            Path              = $DestOU
            Samaccountname    = $user.SamAccountName
            UserPrincipalName = $user.UPN
            Surname           = $user.Surname
            GivenName         = $user.GivenName
            EmailAddress      = $user.EmailAddress
            Department        = $user.Department
            AccountPassword   = $Password
            Enabled           = $True
        }
        New-ADUser @params -PassThru
    }
}

Catch {
    $error[0]
}

Write-Host "Creating Groups..." -ForegroundColor Yellow
Write-Host ""
#endregion

#region Creating the groups from csv
try{
    $CSVGroups = Import-Csv -LiteralPath $CSVPath | Select-Object 'GroupName' -Unique

    foreach ($group in $CSVGroups) {

        $params = @{
            Name           = $group.groupName
            Path           = $DestOU
            GroupScope     = 'Global'
            SamAccountName = $group.groupName
            GroupCategory  = 'Security'
            DisplayName    = $group.groupName
        }

        New-ADGroup @params
        Write-Host "Creating Group "$group.groupName"..." -ForegroundColor Green
        Write-Host ""
    }
}

Catch {
    $error[0]
}

Write-Host "Adding Users to Groups..." -ForegroundColor Yellow
Write-Host ""
#endregion

#region Adding the users to the corresponding groups
try{
    $User2Group = Import-Csv -Path $CSVPath | Select-Object GivenName, GroupName

    foreach ($user in $User2Group) {

        Add-ADGroupMember -Identity $user.groupname -Members $user.GivenName
        Write-Host "Adding User "$user.GivenName" to Group "$user.groupname"..." -ForegroundColor Green
    }
}

Catch {
    $error[0]
}
#endregion

#region Writing some logs and stopping transcript
$log = "$env:userprofile\Desktop\UsersSIDGroups.txt"

(Get-ADUser -Filter * -SearchBase $DestOU -Properties * |
Select-Object Name, MemberOf, SID) |
Out-File -FilePath $log

(Get-ADGroup -Filter * -SearchBase $DestOU |
Select-Object Name, SID) |
Out-File -FilePath $log -Append

Stop-Transcript
#endregion
