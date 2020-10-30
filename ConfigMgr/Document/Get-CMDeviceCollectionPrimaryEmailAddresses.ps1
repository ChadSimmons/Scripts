################################################################################
#.SYNOPSIS
#   Get-CMDeviceCollectionPrimaryEmailAddresses.ps1
#   Get the Primary User and email for all computers in a ConfigMgr device collection
#.DESCRIPTION
#.PARAMETER SiteCode
#   Specifies the ConfigMgr Site Code
#.PARAMETER SiteServer
#   Specifies the ConfigMgr Primary Site Server
#.PARAMETER CollectionName
#   Specifies the name of the ConfigMgr device Collection
#.PARAMETER CollectionID
#   Specifies the ID of the ConfigMgr device Collection
#.PARAMETER OutputFile
#   Specifies the full path and file name of the CSV file receiving the script output
#.EXAMPLE
#   .\Get-CMDeviceCollectionPrimaryEmailAddresses.ps1 -CollectionID USA001D9 -OutputFile U:\USA001D9.csv
#   Get the user information for a Collection ID and save the results to a CSV file
#.EXAMPLE
#   .\Get-CMDeviceCollectionPrimaryEmailAddresses.ps1 -CollectionName "All Active Computers" -OutputFile \\Server\Share\Folder\All_Active_Computers.csv
#   Get the user information for a Collection name and save the results to a CSV file
#.EXAMPLE
#   .\Get-CMDeviceCollectionPrimaryEmailAddresses.ps1 -CollectionName "All Active Computers"
#   Get the user information for a Collection name and only show the results in the PowerShell console
#.LINK
#.NOTES
#   Additional information about the function or script.
#   ========== Keywords ==========
#   Keywords: SCCM MECM MEMCM ConfigMgr Collection User Email
#   ========== Change Log History ==========
#   - 2020/09/03 by Chad Simmons - added Top Console Users and SMS_R_User as a data source
#   - 2020/04/24 by Chad Simmons - added Progress bars
#   - 2020/04/20 by Chad.Simmons@CatapultSystems.com - Created
#   - 2020/04/20 by Chad@ChadsTech.net - Created
#   === To Do / Proposed Changes ===
#   - TODO: Add exclusion list and populate it with End User Computing's Admin IDs
#   - TODO: Address duplicate emails when multiple IDs are detected
#   - TODO: Address scenario where a 2nd user retains the 1st user's info
#   ========== Additional References and Reading ==========
################################################################################
#region    ######################### Parameters and variable initialization ####
[CmdletBinding()]
Param (
	[Parameter(HelpMessage = 'ConfigMgr 3 character Site Code')][ValidateLength(3, 3)][Alias('Site')][string]$SiteCode = 'CM1',
	[Parameter(HelpMessage = 'ConfigMgr Primary Site Server Fully Qualified Domain Name')][ValidateScript( { Resolve-DnsName -Name $_ })][Alias('Server', 'SCCMServer')][string]$SiteServer = 'SCCm12.ati.corp.com',
	[Parameter(HelpMessage = 'ConfigMgr Device Collection Name')][string]$CollectionName,
	[Parameter(HelpMessage = 'ConfigMgr Device Collection ID')][string]$CollectionID,
	[Parameter(HelpMessage = 'Full Path and File Name to output results in CSV format')][string]$OutputFile = $(Join-Path -Path ([System.Environment]::GetFolderPath("Personal")) -ChildPath 'CollectionUserDetails.csv')
)
#region    ######################### Debug code
<#
		$CollectionName="Policy - Workstations for Client Settings - Test"
    $CollectionID="LAB00229"
		If (-not($PSBoundParameters.ContainsKey('SiteCode'))) { [string]$SiteCode = "LAB"; $PSBoundParameters.Add('SiteCode', $SiteCode) }
#>
#endregion ######################### Debug code
#endregion ######################### Parameters and variable initialization ####

#region    ######################### Functions #################################
################################################################################
################################################################################

Function Get-CMUserDeviceAffinityEx ($ComputerName) {
	#Debug: $ComputerName = 'WS12345'
	$CMDevice = Get-CMDevice -Name $ComputerName
	#Get Primary User(s) of the Device
	$DevicePrimaryUsers = @((Get-CMUserDeviceAffinity -DeviceName $ComputerName) | Select-Object @{Name = "ComputerName"; Expression = { ($_.ResourceName) } }, UniqueUsername, CreationTime, sources, emailaddress, DisplayName, LastName, FirstName)
	#Get Top Console User(s) of the Device
	If ($DevicePrimaryUsers.UniqueUsername -eq '\' -or $null -eq $DevicePrimaryusers.UniqueUsername -or $DevicePrimaryusers.UniqueUsername -eq $($ADDomainName + '\')) {
		#$TopConsoleUser = (Get-WmiObject -ComputerName $SiteServer -Namespace "root\SMS\site_$SiteCode" -Query "Select TopConsoleUser FROM SMS_G_System_SYSTEM_CONSOLE_USAGE WHERE ResourceID=$($CMDevice.ResourceID)").TopConsoleUser
		$TopConsoleUser = (Get-CimInstance -ComputerName $SiteServer -Namespace "root\SMS\site_$SiteCode" -ClassName 'SMS_G_System_SYSTEM_CONSOLE_USAGE' -Filter "ResourceID=$($CMDevice.ResourceID)" -Property TopConsoleUser).TopConsoleUser
		$DevicePrimaryUsers = @($CMDevice | Select-Object @{Name = "ComputerName"; Expression = { $_.Name } }, @{Name = "UniqueUsername"; Expression = { $TopConsoleUser } }, CreationTime, sources, emailaddress, DisplayName, LastName, FirstName)
	}
	#Get Last Logon User of the Device
	If ($DevicePrimaryUsers.UniqueUsername -eq '\' -or $null -eq $DevicePrimaryusers.UniqueUsername -or $DevicePrimaryusers.UniqueUsername -eq $($ADDomainName + '\')) {
		$DevicePrimaryUsers = @($CMDevice | Select-Object @{Name = "ComputerName"; Expression = { ($_.Name) } }, @{Name = "UniqueUsername"; Expression = { $_.LastLogonUserDomain + '\' + $_.LastLogonUserName } }, CreationTime, sources, emailaddress, DisplayName, LastName, FirstName)
	}
	If ($DevicePrimaryUsers.UniqueUsername -eq '\' -or $null -eq $DevicePrimaryusers.UniqueUsername -or $DevicePrimaryusers.UniqueUsername -eq $($ADDomainName + '\')) {
		$DevicePrimaryUsers = @($CMDevice | Select-Object @{Name = "ComputerName"; Expression = { ($_.Name) } }, @{Name = "UniqueUsername"; Expression = { $ADDomainName + '\' + $_.LastLogonUser } }, CreationTime, sources, emailaddress, DisplayName, LastName, FirstName)
	}
	If ($DevicePrimaryUsers.UniqueUsername -eq '\' -or $null -eq $DevicePrimaryusers.UniqueUsername -or $DevicePrimaryusers.UniqueUsername -eq $($ADDomainName + '\')) { $DevicePrimaryUsers.UniqueUsername = $null }

	#Get User Details
	If ($DevicePrimaryUsers.count -ge 1) {
		#Get Email Address for each Primary User of the Device
		ForEach ($User in $DevicePrimaryUsers) {
			#Get User details from ConfigMgr if possible
			#$CMUser = Get-WmiObject -ComputerName $SiteServer -Namespace "root\SMS\site_$SiteCode" -Query "SELECT * FROM SMS_R_User WHERE UniqueUserName = '$($user.UniqueUsername.replace('\','\\'))'"
			$CMUser = Get-CimInstance -ComputerName $SiteServer -Namespace "root\SMS\site_$SiteCode" -ClassName 'SMS_R_User' -Filter "UniqueUserName = '$($user.UniqueUsername.replace('\','\\'))'"
			If ($CMUser) {
				$User.emailaddress = If ($CMUser.mail.length -gt 0) { "$($CMUser.mail);" }
				$User.DisplayName = $CMUser.DisplayName
				$User.LastName = $CMUser.Surname
				$User.FirstName = $CMUser.GivenName
				#physicalDeliveryOfficeName
				#mobile telephoneNumber
				#employeeID
				#employeeType
				If ($User.UniqueUsername.length -eq 1) { $User.UniqueUsername = '' }
			}
			#Get User details from Active Directory if not possible from ConfigMgr
			If ($User.emailaddress.length -lt 1) {
				#remove the domain from the username
				$UserID = $($User.UniqueUsername).split('\')[1]
				If ($UserID) {
					Write-Verbose "Getting Active Directory user $UserID..."
					try {
						$ADUser = Get-ADUser -Identity $UserID -Properties emailaddress, Surname, GivenName, DisplayName, EmployeeID, sAMAccountName -ErrorAction SilentlyContinue
					} catch {}
					If ($null -eq $ADUser.EmailAddress) {
						#no email address exists, check if there is an alternate user id
						try {
							$ADUser = Get-ADUser -Filter "EmployeeID -eq $($ADuser.sAMAccountName)" -Properties emailaddress, Surname, GivenName, DisplayName, EmployeeID, sAMAccountName -ErrorAction SilentlyContinue
						} catch {}
					}
					$User.emailaddress = If ($ADUser.emailaddress.length -gt 0) { "$($ADUser.emailaddress);" }
					$User.DisplayName = $ADUser.DisplayName
					$User.LastName = $ADUser.Surname
					$User.FirstName = $ADUser.GivenName
					If ($User.UniqueUsername.length -eq 1) { $User.UniqueUsername = '' }
				}
			}
			Remove-Variable -Name User, CMUser, ADUser -ErrorAction SilentlyContinue
		}
	}
	return $DevicePrimaryUsers
}

#endregion ######################### Functions #################################
################################################################################


If (($Env:SMS_ADMIN_UI_PATH).length -gt 0) {
	Import-Module ($Env:SMS_ADMIN_UI_PATH.Substring(0, $Env:SMS_ADMIN_UI_PATH.Length - 5) + '\ConfigurationManager.psd1')
	$CMSiteCode = Get-PSDrive -PSProvider CMSITE #Get SiteCode
	#Set-Location "$CMSiteCode`:"
	#Pop-Location
}

$ADDomainName = (Get-ADDomain).Name

Push-Location -Path "$SiteCode`:\"
If (-not([string]::IsNullOrEmpty($CollectionID))) {
	Write-Progress -Activity "Getting Collection members" -Status "CollectionID $CollectionID"
	$Computers = Get-CMCollectionMember -CollectionId $CollectionID
} ElseIf (-not([string]::IsNullOrEmpty($CollectionName))) {
	Write-Progress -Activity "Getting Collection members" -Status "CollectionName $CollectionName"
	$Computers = Get-CMCollectionMember -CollectionName $CollectionName
} Else {
	Throw "Either CollctionID or CollectionName must be specified"
}

If ($Computers.Count -lt 1) {
	Throw "No collection members found"
}

#$Computers.count

$Count = 0
$PrimaryUsers = ForEach ($DeviceName in $Computers) {
	$Count++
	Write-Progress -Activity "Getting Primary User for computers" -Status "[$Count of $($Computers.count)] Computer $($DeviceName.name)"
	#DEBUG: $DeviceName = 'WS12345'
	#$Device = Get-CMDevice -Name $DeviceName.Name
	#Get-CMDevice -ResourceId $DeviceName.ResourceID
	$Device = Get-CMResource -ResourceId $DeviceName.ResourceID -Fast
	$DevicePrimaryUsers = Get-CMUserDeviceAffinityEx -ComputerName $DeviceName.Name
	If ($DevicePrimaryUsers.UniqueUsername.length -eq 1) { $DevicePrimaryUsers.UniqueUsername = '' }
	$DevicePrimaryUsers
}
$PrimaryUsers | Format-Table -AutoSize

If ($OutputFile) {
	$PrimaryUsers | Export-Csv -Path "filesystem::$OutputFile" -NoTypeInformation
	Write-Output "Exported results to [$OutputFile]"
}

Pop-Location
