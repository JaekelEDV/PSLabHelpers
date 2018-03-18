<#
      .SYNOPSIS
      Function New-LabUsers creates User-Accounts and Groups for Lab Environments based on a csv-file.
      .DESCRIPTION
      This Script creates User-Accounts for a Lab based on a csv-file.
      Be sure to save the csv as UTF.8. I prefer working with CSVed by Sam Francke, see here: http://csved.sjfrancke.nl/
      Right now the script will look for the headers Name,SamAccountName,UPN,GivenName,Surname,DisplayName,EmailAddress,Group,Department.
      Of course you might add others as well. Adjust the csv and the hashtable for New-ADUser accordingly.
      The users will get a Password which you might set in the parameter section below.
      The Script has two mandatory Parameters (see the parameters help section): You must point to your csv-file and you must
      specify a OU in which the users will be created. If this OU doesn't exist, the script will create it for you.
      If users will be found in the csv that already exist in the AD, you'll get an info but the script will continue.
      If there is a group-header in your csv, this group will also be created and the user will join this group.
      You'll find a corresponding csv for a Lab-Domain named test.local and the most up-to-date version of this script at https://gist.github.com/JaekelEDV.
      Rock it!
      .PARAMETER CSVPath
      Please enter the Path where your csv-file lives.
      .PARAMETER OU
      Please enter the Name of the OU where your new users shall live. There is no need of using the DistinguishedName - just write a name.
      .EXAMPLE
      New-LabUser -CSVPath .\testusers.csv -OU Foo
      .NOTES
      Author: Oliver Jäkel | oj@jaekel-edv.de | @JaekelEDV
#>
Function New-LabUser
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)][string] $CSVPath,
        [Parameter(Mandatory = $true)][string] $OU
    )
    #region (=BEGIN) Starting Transcript, setting Variables checking if AD-Module is present and creating desired OU.

    Begin
    {
        #Set-StrictMode -Version 2.0 - Do not uncomment this. Just for further testing and developing.

        Start-Transcript -Path $env:userprofile\Desktop\LOG-NewLabUser.txt -IncludeInvocationHeader

        $ErrorActionPreference = 'SilentlyContinue' #Just to suppress the ugly ErrorMessages if an object already exists.
        $LoadedModules = (Get-Module).Name
        $CSVUser = Import-Csv -LiteralPath $CSVPath
        $Password = (ConvertTo-SecureString -String 'Pa$$w0rd' -AsPlainText -Force) #Change the Password here if you like.

        if ($LoadedModules -notcontains 'ActiveDirectory')
        {
            Import-Module -Name ActiveDirectory
        }
        else
        {
            Write-Verbose -Message 'ActiveDirectory Module already loaded'
        }

        $VerbosePreference = 'Continue' #No need to type -verbose when running the function.
        $Domain = (Get-ADDomain).DistinguishedName

        Try
        {
            New-ADOrganizationalUnit -Name $OU -ProtectedFromAccidentalDeletion $false -Verbose
        }
        Catch
        {
            Write-Verbose -Message "OU $OU already exists!"
        }

        $DestOU = (Get-ADOrganizationalUnit -Identity "ou=$OU,$Domain")#We need the DN in the next steps!
    }
    #endregion (=END BEGIN)

    #region (=PROCESS) Importing csv-file, creating ADUsers and ADGroups and adding Users to Groups (when defined in csv)

    Process
    {
        foreach ($user in $CSVUser)
        {
            if (Get-ADUser -Filter * -Properties SamAccountName| Where-Object {$_.SamAccountName -eq $User.SamAccountName})
            {Write-Verbose -Message "User $($User.SamAccountName) already exists!"
            }

            else
            {

                $hash = @{
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

                New-ADUser @hash -PassThru
            }

            if (Get-ADGroup -Filter * -Properties SamAccountName| Where-Object {$_.SamAccountName -eq $User.Group})
            {Write-Verbose -Message "Group $($User.Group) already exists!"

                $groups = ($user).Department
                $members = Get-ADUser -Filter * -SearchBase $DestOU -Properties department | Where-Object {$_.department -eq $groups}

                Add-ADGroupMember -Identity $groups -Members $members
            }

            else
            {

                New-ADGroup -Name $user.Group -SamAccountName $user.Group -GroupCategory Security -GroupScope Global -DisplayName $user.Group -Path $DestOU -Verbose

                $groups = ($user).Department
                $members = Get-ADUser -Filter * -SearchBase $DestOU -Properties department | Where-Object {$_.department -eq $groups}

                Add-ADGroupMember -Identity $groups -Members $members
            }
        }
    }
    #endregion (=END PROCESS)

    #region (=END) Create log with User, Groups SID Info, stopping Transcript, cleaning.

    End
    {
        Write-Verbose -Message 'Ready! All Users and Groups successfully created!'
        Write-Verbose -Message 'Writing another log-file: User, SID and GroupMembership'

        $log = "$env:userprofile\Desktop\UsersSIDGroups.txt"

        (Get-ADUser -Filter * -SearchBase $DestOU | Select-Object Name, SID) | Out-File -FilePath $log
        (Get-ADGroup -Filter * -SearchBase $DestOU | Select-Object Name, SID) | Out-File -FilePath $log
        (Get-ADUser -Filter * -SearchBase $DestOU -Properties * | Select-Object Name, MemberOf) | Out-File -FilePath $log

        $VerbosePreference = 'SilentlyContinue'
        $ErrorActionPreference = 'Continue'

        Stop-Transcript
    }
    #endregion (=END END)

}
