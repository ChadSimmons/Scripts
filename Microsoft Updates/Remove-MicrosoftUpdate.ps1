[string]$KBid = '5020023' #November 8, 2022—KB5020023 (Monthly Rollup) https://support.microsoft.com/en-us/topic/november-8-2022-kb5020023-monthly-rollup-9ac62145-0c72-4faf-b5c9-e787f6b19b4d
[string]$PackageNameFilter = 'Package_for_RollupFix*.2251.*' #$null

########################################################################################################################
#.SYNOPSIS
#   Remove-MicrosoftUpdate.ps1
#	Uninstall Microsoft Update / Patch / KB (solution Simple Edition)
#.NOTES
#	Keywords: Uninstall, Remove; Microsoft Support; KB, Update, Patch, Hotfix
#   ========== Change Log History ===============
#   - 2022/12/01 by GitHub @ChadSimmons / Chad.Simmons@Quisitive.com - created

[bool]$HotfixIsInstalled = $(($Hotfixes).HotFixID -contains $('KB' + $KBid))
$PackageName = (Get-WindowsPackage -Online | Where-Object { $_.PackageState -eq 'Installed' -and $_.PackageName -like $PackageNameFilter }).PackageName
If ($null -eq $PackageName -and $HotfixIsInstalled -eq $false) {
	Write-Output $('KB' + $KBid + ' is not installed')
	Exit 0
} Else {
	Write-Output $('Uninstalling KB' + $KBid)
	If ($null -ne $PackageName) {
		Remove-WindowsPackage -PackageName $PackageName -Online -NoRestart -LogPath $("$env:SystemRoot\Logs\KB" + $KBid + '.log')
	}
	If ($HotfixIsInstalled -eq $true) {
		Start-Process -FilePath "$env:SystemRoot\System32\wusa.exe" -ArgumentList "/uninstall /kb:$KBid /quiet /norestart /log:$("$env:SystemRoot\Logs\KB" + $KBid + '.log')" -Wait
	}

	#Check if the registry key RebootRequired is present. It is created when Windows Updates are applied and require a reboot to take place
	$PatchReboot = [bool](Get-ChildItem -Path REGISTRY::"HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired" -ErrorAction SilentlyContinue)

	#Check if the RebootPending key is present. It is created when changes are made to the component store that require a reboot to take place
	$ComponentBasedReboot = [bool](Get-ChildItem -Path REGISTRY::"HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending" -ErrorAction SilentlyContinue)

	#Check if File rename operations are taking place and require a reboot for the operation to take effect
	$PendingFileRename = [bool]((Get-ItemProperty -Path REGISTRY::"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager" -ErrorAction SilentlyContinue).PendingFileRenameOperations)

	#WMI query of the Microsoft Configuration Manager service to check if a reboot is pending
	$ConfigMgrReboot = Invoke-WmiMethod -Namespace 'ROOT\ccm\ClientSDK' -Class CCM_ClientUtilities -Name DetermineIfRebootPending | Select-Object -ExpandProperty 'RebootPending'

	#Update ConfigMgr inventory
	Invoke-WmiMethod -Namespace root\ccm -Class sms_client -Name TriggerSchedule -ArgumentList '{00000000-0000-0000-0000-000000000003}' -ErrorAction Stop # Discovery Data Collection Cycle
	Invoke-WmiMethod -Namespace root\ccm -Class sms_client -Name TriggerSchedule -ArgumentList '{00000000-0000-0000-0000-000000000001}' -ErrorAction Stop # Hardware Inventory Collection Cycle
	Invoke-WmiMethod -Namespace root\ccm -Class sms_client -Name TriggerSchedule -ArgumentList '{00000000-0000-0000-0000-000000000113}' -ErrorAction Stop # Software Update Scan Cycle

	#Test and return reboot pending status
	If ($PatchReboot -eq $true -or $ComponentBasedReboot -eq $true -or $PendingFileRename -eq $true -or $ConfigMgrReboot -eq $true) {
		Write-Output 'Reboot required'
		Exit 3010
	} Else {
		Write-Output 'reboot NOT required'
		Exit 0
	}
}