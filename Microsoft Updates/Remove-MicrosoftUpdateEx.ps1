#requires -Version 3.0
#requires -RunAsAdministrator
#.SYNOPSIS
#   Remove-MicrosoftUpdateEx.ps1
#	Uninstall Microsoft Update / Patch / KB (Extended/Enhanced Edition)
#.NOTES
#	Keywords: Uninstall, Remove; Microsoft Support; KB, Update, Patch, Hotfix
#	TODO: Capture and return uninstall return code
#	TODO: Full CMTrace style logging
#	TODO: Handle multiple KBs/Updates[CmdletBinding()]
Param (
	[Parameter(Mandatory = $false, HelpMessage = 'Microsoft KB identifier (number)')][string]$KBid = '5019959',
	[Parameter(Mandatory = $false, HelpMessage = 'Windows Package Name')][string]$PackageNameFilter = 'Package_for_RollupFix*.2251.*',
	[Parameter][switch]$SkipLogging
)
Function Test-PendingReboot {
	#.Synopsis
	#   PendingRebootReporting.ps1 by Mick Pletcher, modified by @ChadSimmons

	#Checks if the registry key RebootRequired is present. It is created when Windows Updates are applied and require a reboot to take place
	$PatchReboot = Get-ChildItem -Path REGISTRY::"HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired" -ErrorAction SilentlyContinue

	#Checks if the RebootPending key is present. It is created when changes are made to the component store that require a reboot to take place
	$ComponentBasedReboot = Get-ChildItem -Path REGISTRY::"HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending" -ErrorAction SilentlyContinue

	#Checks if File rename operations are taking place and require a reboot for the operation to take effect
	$PendingFileRenameOperations = (Get-ItemProperty -Path REGISTRY::"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager" -ErrorAction SilentlyContinue).PendingFileRenameOperations
	If ($PendingFileRenameOperations -eq $null) { $PendingFileRename = $false } else { $PendingFileRename = $true }

	#Performs a WMI query of the configuration manager service to check if a reboot is pending
	$ConfigurationManagerReboot = Invoke-WmiMethod -Namespace 'ROOT\ccm\ClientSDK' -Class CCM_ClientUtilities -Name DetermineIfRebootPending | Select-Object -ExpandProperty 'RebootPending'

	#Test and return reboot pending status
	If (($null -ne $PatchReboot) -or ($null -ne $ComponentBasedReboot) -or ($PendingFileRename -eq $true) -or ($ConfigurationManagerReboot -eq $true)) {
		Write-Output 'Reboot required'
		Return 3010
	} Else {
		Write-Output 'reboot NOT required'
		Return 0
	}
}
Function Update-ConfigMgrInventory {
	Invoke-WmiMethod -Namespace root\ccm -Class sms_client -Name TriggerSchedule -ArgumentList '{00000000-0000-0000-0000-000000000003}' -ErrorAction Stop # Discovery Data Collection Cycle
	Invoke-WmiMethod -Namespace root\ccm -Class sms_client -Name TriggerSchedule -ArgumentList '{00000000-0000-0000-0000-000000000001}' -ErrorAction Stop # Hardware Inventory Collection Cycle
	Invoke-WmiMethod -Namespace root\ccm -Class sms_client -Name TriggerSchedule -ArgumentList '{00000000-0000-0000-0000-000000000113}' -ErrorAction Stop # Software Update Scan Cycle
}

$Hotfixes = Get-HotFix | Select-Object CSName, HotFixID, Description, InstalledBy, InstalledOn, @{Name = 'InventoriedOn'; Expression = { $(Get-Date) } }
If ($SkipLogging -ne $true) {
	$Hotfixes | Sort-Object InstalledOn | Export-Csv -Path "$env:SystemRoot\Logs\Hotfixes Installed.csv" -Append -NoTypeInformation
}
[bool]$HotfixIsInstalled = $(($Hotfixes).HotFixID -contains $('KB' + $KBid))
$PackageName = (Get-WindowsPackage -Online | Where-Object { $_.PackageState -eq 'Installed' -and $_.PackageName -like $PackageNameFilter }).PackageName

If ($null -eq $PackageName -and $HotfixIsInstalled -eq $false) {
	Write-Output 'KB' + $KBid + ' is not installed'
	Exit 0
} Else {
	#Uninstall the hotfix / update
	If ($null -ne $PackageName) {
		Remove-WindowsPackage -PackageName $PackageName -Online -NoRestart -LogPath $("$env:SystemRoot\Logs\KB" + $KBid + '.log')
	}
	If ($HotfixIsInstalled -eq $true) {
#TODO: Verify this does not hang		Start-Process -FilePath "$env:SystemRoot\System32\wusa.exe" -ArgumentList "/uninstall /kb:$KBid /quiet /norestart /log:$("$env:SystemRoot\Logs\KB" + $KBid + '.log')" -Wait
	}

	Update-ConfigMgrInventory

	[bool]$HotfixIsInstalled = $((Get-HotFix).HotFixID -contains $('KB' + $KBid))
	$PackageName = (Get-WindowsPackage -Online | Where-Object { $_.PackageState -eq 'Installed' -and $_.PackageName -like $PackageNameFilter }).PackageName
	If ($null -eq $PackageName -and $HotfixIsInstalled -eq $true) {
		Write-Output 'KB' + $KBid + ' uninstall successful'

		#Trigger a system reboot if one is pending
		$ExitCode = Test-PendingReboot
		Write-Output "Complete.  Exiting with return code $ExitCoe"
		Exit $ExitCode
	} Else {
		Write-Output 'KB' + $KBid + ' uninstall failed.  Retry later'
		Exit 999 # ConfigMgr Execution Failure Retry Error Codes https://home.memftw.com/configmgr-and-failed-program-retry/
	}
}