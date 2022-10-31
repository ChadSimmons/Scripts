#r e q u i r e s -RunAsAdministrator #this doesn't support PowerShell 3.0
#r e q u i r e s -Version 2.0 ... but OpenRemoteBaseKey doesn't work with PowerShell 2.0
################################################################################
#.SYNOPSIS
#   Get-InstalledAppsViaRegistry.ps1
#   Export Add/Remove Programs (Programs and Features) 32-bit and 64-bit system-level entries from the Windows Registry
#.DESCRIPTION
#.EXAMPLE
#   Get-InstalledAppsRegistry.ps1
#.EXAMPLE
#   Get-InstalledAppsRegistry.ps1 -InventoryFile "$env:SystemDrive\Users\Public\Documents\InstalledSoftware-$($env:ComputerName).csv"
#.LINK
#.NOTES
#   ========== Change Log History ==========
#   - 2022/10/31 by Chad.Simmons@CatapultSystems.com - streamlined code; added support for current user installed apps
#   - 2019/07/17 by Chad.Simmons@CatapultSystems.com - addressed issue with 32-bit systems failing.  Added CSV formatted output
#   - 2019/04/09 by Chad.Simmons@CatapultSystems.com - refactored
#   - 2018/06/22 by magil538 - Created
#   === To Do / Proposed Changes ===
#   - TODO: Support installs from all users with a profile #https://community.idera.com/database-tools/powershell/ask_the_experts/f/powershell_remoting-24/18381/remotely-querying-a-key-on-all-user-s-registry-on-multiple-machines
#   - TODO: Support report history files
################################################################################

[CmdletBinding()]
Param (
	[Parameter()][string]$InventoryFile = $(Join-Path -Path $env:SystemDrive -ChildPath 'Users\Public\Documents\InstalledSoftware.txt'),
	[Parameter()][string]$CSVInventoryFile
)
#$VerbosePreference = 'Continue'
################################################################################
Function Get-InstalledApps {
	param (
		[Parameter(Mandatory = $true)][ValidateNotNull()][string]$keyPath,
		[Parameter(Mandatory = $true)][ValidateNotNull()][string]$bitness,
		[Parameter(Mandatory = $true)][ValidateNotNull()][string]$InventoryFile
    )
	$Count = 0
	If ($bitness -eq 'x64')	{
		$reg = [microsoft.win32.registrykey]::OpenRemoteBaseKey('LocalMachine', $ComputerName, 'Registry64')
	} else {
		$reg = [microsoft.win32.registrykey]::OpenRemoteBaseKey('LocalMachine', $ComputerName, 'Registry32')
	}
	Add-Content -Path $InventoryFile -value "$bitness Application List"
	Add-Content -Path $InventoryFile -value ' '
	#Drill down into the Uninstall key using the OpenSubKey Method
	$regkey = $reg.OpenSubKey($keyPath)
	#Retrieve an string array that contains all the subkey names
	$subkeys = $regkey.GetSubKeyNames()
	foreach ($key in $subkeys) {
		If ($key) {
			$thiskey = $keyPath + '\\' + $key
			$thissubkey = $reg.OpenSubKey($thiskey)
			try {
				$displayname = $thissubkey.getvalue("Displayname")
				If ($displayname) {
					$Count++
					Add-Content -Path $InventoryFile -value "$Count.  $displayname"
					Write-Verbose -Message "found $displayname"
				}
			} catch {
				#subkey does not contain a DisplayName Value
			}
		}
	}
    Write-Verbose -Message "$bitness`: $Count Applications found"
	$script:TotalApps += $Count
}

Function Get-InstalledAppsHT {
	param (
		[Parameter(Mandatory = $true)][ValidateNotNull()][string]$keyPath,
		[Parameter(Mandatory = $true)][ValidateNotNull()][string]$bitness,
		[Parameter(Mandatory = $true)][ValidateNotNull()][string]$RegHive = 'LocalMachine'
    )
	If ($bitness -eq 'x64')	{
		$reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey($RegHive, $ComputerName, 'Registry64')
	} Else {
		$reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey($RegHive, $ComputerName, 'Registry32')
	}
	Switch ($RegHive) {
		'CurrentUser' {	$User = $reg.OpenSubKey('Volatile Environment').GetValue('USERNAME') }
		'AllUsers' { $User = 'AllUsers' }
		Default { $User = 'System' }
	}

	$RegKey = $reg.OpenSubKey($keyPath) #Drill down into the Uninstall key using the OpenSubKey Method
	#Retrieve an string array that contains all the subkey names
	$SubKeys = $RegKey.GetSubKeyNames()
	$AppList = @()
	ForEach ($key in $SubKeys) {
		If ($key) {
			try {
				$ThisKey = $keyPath + '\\' + $key
				$ThisSubKey = $reg.OpenSubKey($ThisKey)
				$AppDetails = New-Object -TypeName PSObject -Property @{'Bitness' = $bitness; 'User' = $User; 'Publisher' = ''; 'DisplayName' = ''; 'DisplayVersion' = ''; 'InstallDate' = '' }
				$AppDetails.DisplayName = $ThisSubKey.GetValue('Displayname')
				Write-Verbose -Message "found $($AppDetails.DisplayName)"
			} catch {
				#OpenSubKey does not contain a DisplayName Value
			}
			If (-not([string]::IsNullOrEmpty($AppDetails.DisplayName))) {
				$AppDetails.Publisher = $ThisSubKey.GetValue("Publisher")
				$AppDetails.DisplayVersion = $ThisSubKey.GetValue('DisplayVersion')
				$AppDetails.InstallDate = $ThisSubKey.GetValue('InstallDate')
				$AppList += $AppDetails #output hashtable to add to array
			}
		}
	}
	Return $AppList
}
################################################################################

$script:TotalApps = 0

If ([string]::IsNullOrEmpty($CSVInventoryFile)) {
	$CSVInventoryFile = [IO.Path]::ChangeExtension($InventoryFile,'csv')
}

$TargetDir = Split-Path -Path $InventoryFile -Parent
if (!(Test-Path -Path $TargetDir -PathType Container)) {
	New-Item -ItemType directory -Path $TargetDir | Out-Null
}
if (Test-Path -Path $InventoryFile -PathType Leaf) {
	Remove-Item $InventoryFile
}
New-Item -ItemType file -Path $InventoryFile | Out-Null


$InstalledAppsSummary = New-Object -TypeName PSObject -Property @{'Bitness'='Summary'; 'User'='All'; 'Publisher'=0; 'DisplayName'=0; 'DisplayVersion'=0; 'InstallDate'=$(Get-Date -Format 's')}

Get-InstalledApps -bitness 'x86' -keyPath 'SOFTWARE\\Wow6432Node\\Microsoft\\Windows\\CurrentVersion\\Uninstall' -InventoryFile $InventoryFile
$InstalledApps = Get-InstalledAppsHT -bitness 'x86' -keyPath 'SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall' -RegHive 'LocalMachine'
$InstalledApps += Get-InstalledAppsHT -bitness 'x86' -keyPath 'SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall' -RegHive 'CurrentUser'
$InstalledAppsSummary.DisplayVersion = $InstalledApps.count

$OSArchitecture = (Get-WmiObject -Namespace 'root\CIMv2' -Class 'Win32_OperatingSystem' -Property OSArchitecture).OSArchitecture
If ($OSArchitecture -eq '64-bit') {
	Get-InstalledApps -bitness 'x64' -keyPath 'SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall' -InventoryFile $InventoryFile
	$InstalledApps += Get-InstalledAppsHT -bitness 'x64' -keyPath 'SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall' -RegHive 'LocalMachine'
	$InstalledApps += Get-InstalledAppsHT -bitness 'x64' -keyPath 'SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall' -RegHive 'CurrentUser'
	$InstalledAppsSummary.DisplayName = $InstalledApps.count - $InstalledAppsSummary.DisplayVersion
}

try {
	$InstalledAppsSummary.Publisher = $($InstalledAppsSummary.DisplayName + $InstalledAppsSummary.DisplayVersion).toString() + ' total apps'
	$InstalledAppsSummary.DisplayName = $($InstalledAppsSummary.DisplayName).toString() + ' 64-bit apps'
	$InstalledAppsSummary.DisplayVersion = $($InstalledAppsSummary.DisplayVersion).toString() + ' 32-bit apps'

	$InstalledApps 		  | Select-Object Bitness,User,Publisher,DisplayName,DisplayVersion,InstallDate | Export-CSV -NoTypeInformation -Delimiter "`t" -Path $CSVInventoryFile
	$InstalledAppsSummary | Select-Object Bitness,User,Publisher,DisplayName,DisplayVersion,InstallDate | Export-CSV -NoTypeInformation -Delimiter "`t" -Path $CSVInventoryFile -Append
} catch {}

Write-Output "$($InstalledAppsSummary.Publisher) were found"