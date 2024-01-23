#requires -version 2.0
####requires -RunAsAdministrator #not supported by PowerShell 2.0
################################################################################
#.SYNOPSIS
#   Update-Drivers.ps1
#   Upgrade Windows hardware drivers
#.DESCRIPTION
#   Upgrade hardware drivers for Microsoft Windows 10 / 8.1 / 8 / 7 using PNPUtil.exe
#.PARAMETER Stage
#   Do not install drivers, only stage them in the driver store
#.EXAMPLE
#   Update-Drivers.ps1
#   Install drivers in the script's path
#.EXAMPLE
#   Update-Drivers.ps1 -Stage
#   Stage drivers in the script's path into the Windows Driver Store
#.LINK
#   PNPUtil.exe: https://docs.microsoft.com/en-us/windows-hardware/drivers/devtest/pnputil
#   PNPUtil error code 9009: https://www.itninja.com/question/inf-driver-update-via-k1000-managed-install
#   PNPUtil error code 259: https://www.sysmansquad.com/2020/05/15/modern-driver-management-with-the-administration-service
#.NOTES
#   ========== Change Log History ==========
#   - 2020/09/09 by Chad.Simmons@CatapultSystems.com - Added SYSNATIVE logic for PNPUtil.exe exit code 9009
#   - 2020/09/09 by Chad.Simmons@CatapultSystems.com - Added script header and exit code 3010 logic
#   - 2020/08/28 by Chad.Simmons@CatapultSystems.com - Created
#   === To Do / Proposed Changes ===
#   TODO: Add CMTrace style logging and Write-Progress
#   TODO: Call PNPUtil.exe for each INF file for more accurrate return code per documentation
#	TODO: Handle 7z, Zip and zPaq compressed archives in addition to WIM file
#	TODO: Consider handling multiple compressed archive files and autodetecting the WIM file name
################################################################################
#region    ######################### Parameters and variable initialization ####
[CmdletBinding()] #(SupportsShouldProcess=$false, ConfirmImpact="Low")
Param (
	[Parameter(HelpMessage = 'Stage drivers instead of installing them')][Switch]$Stage
)

Write-Verbose -Message 'Get Script path and name'
If ($psISE) { $ScriptFullPath = $psISE.CurrentFile.FullPath }
Else {
	If (Test-Path -LiteralPath 'variable:HostInvocation') { $InvocationInfo = $HostInvocation } Else { $InvocationInfo = $MyInvocation }
	$ScriptFullPath = $InvocationInfo.MyCommand.Definition
	Write-Verbose -Message "ScriptFullPath is [$ScriptFullPath]"
}
$ScriptPath = Split-Path -Path $ScriptFullPath -Parent
$ScriptFile = Split-Path -Path $ScriptFullPath -Leaf

Write-Verbose -Message 'Get ConfigMgr Client log path'
try {
	$ConfigMgrClientLogsPath = Get-ItemProperty "HKLM:\Software\Microsoft\CCM\Logging\@global" -ErrorAction Stop | Select-Object -ExpandProperty LogDirectory
} catch {
	try { $ConfigMgrClientLogsPath = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\SMS\Client\Configuration\Client Properties" -ErrorAction Stop | Select-Object -ExpandProperty 'Local SMS Path' }
	catch {
		try { $ConfigMgrClientLogsPath = Split-Path -Path $(Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\services\CcmExec" -ErrorAction Stop | Select-Object -ExpandProperty ImagePath) -Parent }
		catch { $ConfigMgrClientLogsPath = Join-Path -Path $env:SystemRoot -ChildPath 'CCM' }
	}
	If ($ConfigMgrClientLogsPath -like '"*') {
		#"`"*"
		#handle case where a double-quote starts the variable and optionally ends it
		$ConfigMgrClientLogsPath = $ConfigMgrClientLogsPath.Split('"')[1]
	}
	$ConfigMgrClientLogsPath = "$ConfigMgrClientLogsPath\Logs"
}
Write-Verbose -Message "ConfigMgrClientLogsPath is [$ConfigMgrClientLogsPath]"


$PNPUtilLogFile = Join-Path -Path $ConfigMgrClientLogsPath -ChildPath 'Update-Drivers.log'
Write-Verbose -Message "PNPUtilLogFile is [$PNPUtilLogFile]"
If (Test-Path -Path $PNPUtilLogFile -PathType Leaf) {
	$PNPUtilLogFileBackup = $([System.IO.Path]::GetFileNameWithoutExtension($PNPUtilLogFile)) + '-' + $(Get-Date -Date (Get-Item -Path $PNPUtilLogFile).LastWriteTime -Format 'yyyyMMdd-HHmmss') + (Get-Item -Path $PNPUtilLogFile).Extension
	$PNPUtilLogFileBackup = Join-Path -Path $(Split-Path -Path $PNPUtilLogFile -Parent) -ChildPath $PNPUtilLogFileBackup
	Move-Item -Path $PNPUtilLogFile -Destination $PNPUtilLogFileBackup
}

Write-Verbose -Message 'Mount WIM file if it exists'
$WIMfile = Join-Path -Path $ScriptPath -ChildPath 'Drivers.wim'
Write-Verbose -Message "WIMfile is [$WIMfile]"
If (Test-Path -Path $WIMfile) {
	$StagePath = Join-Path -Path $env:SystemDrive -ChildPath '_DriversWIM'
	Write-Verbose -Message "StagePath is [$StagePath]"
	If (-not(Test-Path -Path $StagePath)) { New-Item -Path $StagePath -ItemType Directory -ErrorAction Stop }
	#try { Mount-WindowsImage -Path $StagePath -ImagePath $WIMfile -Index 1 -ReadOnly -ErrorAction Stop }
	try {
		Start-Process -FilePath "$env:SystemRoot\System32\DISM.exe" -ArgumentList "/Mount-Wim  /MountDir:`"$StagePath`" /WimFile:`"$WIMfile`" /index:1 /ReadOnly" -NoNewWindow
		Start-Sleep -Seconds 5 #using -Wait with DISM hangs in PowerShell 2.0
	} catch { throw $_ }
	#TODO: Handle *.7z, *.zip and *.zPaq compressed archives
} Else {
	$StagePath = $ScriptPath
}

Write-Verbose -Message 'Export inventory of current drivers'
Get-WmiObject Win32_PnPSignedDriver | Select-Object Manufacturer, DriverProviderName, FriendlyName, DeviceName, DriverVersion, DriverDate, InfName, IsSigned, DeviceID, Description | Sort-Object DeviceID | Export-Csv -NoTypeInformation -Path $($ConfigMgrClientLogsPath + '\DriverInventory.' + $(Get-Date -Format 'yyyyMMdd_HHmmss') + '.csv')

Write-Verbose -Message 'add Install parameter to PNPUtil if not Staging'
If ($Stage) { $cmdOptionalParms = '' }
Else { $cmdOptionalParms = '/install' }

try {
	$rc = (Start-Process -FilePath "$env:SystemRoot\System32\PnPutil.exe" -ArgumentList "/add-driver `"$StagePath\*.inf`" /subdirs $cmdOptionalParms" -RedirectStandardOutput $PNPUtilLogFile -Wait -PassThru -ErrorAction Stop).ExitCode #-WindowStyle Hidden
} catch { #If ($rc -eq 9009) {
	$rc = (Start-Process -FilePath "$env:SystemRoot\SysNative\PnPutil.exe" -ArgumentList "/add-driver `"$StagePath\*.inf`" /subdirs $cmdOptionalParms" -RedirectStandardOutput $PNPUtilLogFile -Wait -PassThru -ErrorAction Stop).ExitCode #-WindowStyle Hidden
}

Write-Verbose -Message 'Export inventory of updated drivers'
Get-WmiObject Win32_PnPSignedDriver | Select-Object Manufacturer, DriverProviderName, FriendlyName, DeviceName, DriverVersion, DriverDate, InfName, IsSigned, DeviceID, Description | Sort-Object DeviceID | Export-Csv -NoTypeInformation -Path $($ConfigMgrClientLogsPath + '\DriverInventory.' + $(Get-Date -Format 'yyyyMMdd_HHmmss') + '.csv')

Write-Verbose -Message 'Dismount WIM file if it exists'
If (Test-Path -Path $WIMfile) {
	#try { Dismount-WindowsImage -Path $StagePath -Discard -ErrorAction Stop }  #Not support in PowerShell 2.0
	try {
		Start-Process -FilePath "$env:SystemRoot\System32\DISM.exe" -ArgumentList "/Unmount-Wim /MountDir:`"$StagePath`" /Discard" -NoNewWindow
		Start-Sleep -Seconds 5 #using -Wait with DISM sometimes hangs in PowerShell 2.0
	} catch { Write-Error $_ }
	If (Test-Path -Path $StagePath) { Remove-Item -Path $StagePath -ErrorAction Stop }
}

Write-Verbose -Message 'Get last line of Parse PNPUtil log file'
#$PNPUtilOutput = Get-Content -Path $PNPUtilLogFile -Last 1 #not supported by PowerShell 2.0
ForEach ($PNPUtilOutput in $(Get-Content -Path $PNPUtilLogFile)) {}
Write-Verbose -Message "Last line is [$PNPUtilOutput]"

Write-Verbose -Message "Add PNPUtil.exe exit code to log file.  PNPUtil.exe completed with exit code $rc"
Add-Content -Path "$PNPUtilLogFile" -Value "PNPUtil.exe completed at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') with exit code $rc"

#Parse PNPUtil log file looking for known completion status
If ($PNPUtilOutput -eq 'System reboot is needed to complete install operations!') { $ExitCode = 3010 }
ElseIf ($rc -eq 259) { $ExitCode = 3010 }
ElseIf ($rc -eq 9009) { $ExitCode = 999 }
Else { $ExitCode = $rc }

Write-Verbose -Message "Add script exit code to log file.  Script completed with exit code $ExitCode"

Add-Content -Path "$PNPUtilLogFile" -Value "$ScriptFile was modified on $(Get-Date -Date (Get-Item -Path C:\files\ComputerList.csv).LastWriteTime -Format 'yyyy-MM-dd HH:mm:ss')"
Add-Content -Path "$PNPUtilLogFile" -Value "$ScriptFile completed at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') with exit code $ExitCode"

EXIT $ExitCode