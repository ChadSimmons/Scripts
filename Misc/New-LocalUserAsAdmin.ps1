################################################################################
#.SYNOPSIS
#   New-LocalUserAsAdmin.ps1
#   Create a local user account if it does not exist and prevent the user from changing the password
#   Set the local user account to expire in a specified number of hours
#   Add the local user account to the local Administrators group.
#.PARAMETER UserID
#   Specifies the User ID (User Name) to create or update
#.PARAMETER GroupName
#   Specifies the name of the local user group to add the user to
#.PARAMETER PasswordNeverExpires
#   Specifies the if the password should expire
#.PARAMETER AccountExpiresInHours
#   Specifies the number of hours the account will be active until it expires
#.EXAMPLE
#   New-LocalUserAsAdmin.ps1 -AccountExpiresInHours 6 -UserID Chad
#.NOTES
#   - 2021/02/17 by Chad.Simmons@CatapultSystems.com - added support for PasswordNeverExpires and more
#   - 2021/02/03 by Chad.Simmons@CatapultSystems.com - Created
################################################################################

param (
    [Parameter()][ValidatePattern('^[a-z_]([a-z0-9_-]{0,31}|[a-z0-9_-]{0,30}\$)$')][string]$UserID,
    [Parameter()][string]$GroupName = 'Administrators',
    [Parameter()][bool]$PasswordNeverExpires = $false,
    [Parameter()][ValidateRange(0,8760)][int16]$AccountExpiresInHours = 0
)
If ([string]::IsNullOrEmpty($UserID)) { $UserID = 'LocalUser' }
Else { $UserID = 'Local_' + $UserID }

[string]$Password = "$($env:ComputerName + '-' + [string](Get-Date -Format 'yyyy-MM-dd'))"
[System.Security.SecureString]$Password = ConvertTo-SecureString -String $Password -AsPlainText -Force

If (-not(Get-LocalUser -Name "$UserID" -ErrorAction SilentlyContinue)) {
    Write-Verbose 'Creating local user'
    Try { $User = New-LocalUser -FullName 'Local Standard User' -Name "$UserID" -UserMayNotChangePassword -Password $Password } Catch { Throw $_ }
}
$User = Get-LocalUser -Name "$UserID" -ErrorAction SilentlyContinue
If ($User) {
	If ($AccountExpiresInHours -eq 0) { Try { Write-Verbose 'Setting AccountExpires'; Set-LocalUser -Name "$UserID" -AccountNeverExpires } Catch { Throw $_ } }
	Else { Try { Write-Verbose 'Setting AccountExpires'; Set-LocalUser -Name "$UserID" -AccountExpires $((Get-Date).AddHours($ExpiresInHours)) } Catch { Throw $_ }	}
	Try { Write-Verbose 'Setting PasswordNeverExpires'; Set-LocalUser -Name "$UserID" -PasswordNeverExpires $PasswordNeverExpires } Catch { Throw $_ }
    Try { Write-Verbose 'Enabling local user'; [void](Enable-LocalUser -Name "$UserID") } Catch { } #throw $_ }
    Try { Write-Verbose "Adding local user to $GroupName group"; Add-LocalGroupMember -Group "$GroupName" -Member "$UserID" -ErrorAction Stop; Write-Output "$UserID added to local $GroupName group" }
    Catch [Microsoft.PowerShell.Commands.MemberExistsException] { Write-Output "$UserID is a member of the local $GroupName group" }
    Catch { throw $_ }
} Else { return 2 }
