################################################################################
#.SYNOPSIS
#   New-LocalUserAsAdmin.ps1
#   Create a local user account if it does not exist and prevent the user from changing the password
#   Set the local user account to expire in a specified number of hours
#   Add the local user account to the local Administrators group.
#.PARAMETER UserID
#   Specifies the User ID (User Name) to create or update
#.PARAMETER ExpiresInHours
#   Specifies the number of hours the account will be active until it expires
#.EXAMPLE
#   New-LocalUserAsAdmin.ps1 -ExpiresInHours 6 -UserID Chad
#.NOTES
#   - yyyy/mm/dd by Chad@ChadsTech.net - Created
################################################################################

param (
    [Parameter()][ValidatePattern('^[a-z_]([a-z0-9_-]{0,31}|[a-z0-9_-]{0,30}\$)$')][string][string]$UserID,
    [Parameter()][ValidateRange(1,168)][int]$ExpiresInHours = 4
)
If ([string]::IsNullOrEmpty($UserID)) { $UserID = 'LocalUser' }
Else { $UserID = 'Local_' + $UserID }

$Password = ConvertTo-SecureString -String "$($env:ComputerName + '-' + [string](Get-Date -format 'yyyy-MM-dd'))" -AsPlainText -Force

If (-not(Get-LocalUser -Name "$UserID" -ErrorAction SilentlyContinue)) {
    Write-Verbose 'Creating local user'
    try { $User = New-LocalUser -FullName 'Local Standard User' -Name "$UserID" -UserMayNotChangePassword -Password $Password } catch { throw $_ }
}
$User = Get-LocalUser -Name "$UserID" -ErrorAction SilentlyContinue
If ($User) { 
    try { Write-Verbose 'Setting AccountExpires'; Set-LocalUser -Name "$UserID" -AccountExpires $((Get-Date).AddHours($ExpiresInHours)) } catch { throw $_ }
    #try { Write-Verbose 'Enabling local user'; [void](Enable-LocalUser -Name "$UserID") } catch { throw $_ }
    try { Write-Verbose 'Adding local user to Administrators group'; Add-LocalGroupMember -Group 'Administrators' -Member "$UserID" -ErrorAction Stop; Write-Output "$UserID added to local Adminsitrators group" } 
    catch [Microsoft.PowerShell.Commands.MemberExistsException] { Write-Output "$UserID is a member of the local Adminsitrators group" }
    catch { throw $_ }
} Else { return 2 }
