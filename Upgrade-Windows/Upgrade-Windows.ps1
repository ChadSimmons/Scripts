


Function Clean-WUA {
	#get WUA state
	#stop WUA
	#delete WUA files
	#If WUA was started, restart
}

Function Invoke-CleanMgr {
	#.Synopsis
	#   Run Desktop Cleanup Manager
	#.Description
	#   Configure CleanMgr SageSet registry values
	#   RunWait CleanMgr.exe
	#.Link
	#   Based on https://gregramsey.net/2014/05/14/automating-the-disk-cleanup-utility/
	#   Based on https://deploymentbunny.com/2014/06/05/nice-to-know-get-rid-of-all-junk-before-sysprep-and-capture-when-creating-a-reference-image-in-mdt/
	#            https://github.com/DeploymentBunny/Files/blob/master/Tools/Action-CleanupBeforeSysprep/Action-CleanupBeforeSysprep.wsf
	#   http://support.microsoft.com/kb/253597

	#Capture current free disk space on Drive C
	$FreeSpaceBefore = (Get-WmiObject win32_logicaldisk -filter "DeviceID='C:'" | select Freespace).FreeSpace

	Set-Variable -Name SageRun -Value 1703
	Set-Variable -Name RegPath -Value 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches'
	Set-Varibale -Name RegName -Value "StateFlags$SageRun"
	#Set StateFlags0012 setting for each item in Windows 8.1 disk cleanup utility
	if (-not (get-itemproperty -path "$RegPath\Active Setup Temp Folders" -name $RegPath -ErrorAction SilentlyContinue)) {
		set-itemproperty -path "$RegPath\Active Setup Temp Folders" -name $RegName -type DWORD -Value 2
		set-itemproperty -path "$RegPath\BranchCache" -name $RegName -type DWORD -Value 2
		set-itemproperty -path "$RegPath\Downloaded Program Files" -name $RegPath -type DWORD -Value 2
		set-itemproperty -path "$RegPath\Internet Cache Files" -name $RegPath -type DWORD -Value 2
		set-itemproperty -path "$RegPath\Memory Dump Files" -name $RegPath -type DWORD -Value 2
		set-itemproperty -path "$RegPath\Old ChkDsk Files" -name $RegPath -type DWORD -Value 2
		set-itemproperty -path "$RegPath\Previous Installations" -name $RegPath -type DWORD -Value 2
		set-itemproperty -path "$RegPath\Recycle Bin" -name $RegPath -type DWORD -Value 2
		set-itemproperty -path "$RegPath\Service Pack Cleanup" -name $RegPath -type DWORD -Value 2
		set-itemproperty -path "$RegPath\Setup Log Files" -name $RegPath -type DWORD -Value 2
		set-itemproperty -path "$RegPath\System error memory dump files" -name $RegPath -type DWORD -Value 2
		set-itemproperty -path "$RegPath\System error minidump files" -name $RegPath -type DWORD -Value 2
		set-itemproperty -path "$RegPath\Temporary Files" -name $RegPath -type DWORD -Value 2
		set-itemproperty -path "$RegPath\Temporary Setup Files" -name $RegPath -type DWORD -Value 2
		set-itemproperty -path "$RegPath\Thumbnail Cache" -name $RegPath -type DWORD -Value 2
		set-itemproperty -path "$RegPath\Update Cleanup" -name $RegPath -type DWORD -Value 2
		set-itemproperty -path "$RegPath\Upgrade Discarded Files" -name $RegPath -type DWORD -Value 2
		set-itemproperty -path "$RegPath\User file versions" -name $RegPath -type DWORD -Value 2
		set-itemproperty -path "$RegPath\Windows Defender" -name $RegPath -type DWORD -Value 2
		set-itemproperty -path "$RegPath\Windows Error Reporting Archive Files" -name $RegPath -type DWORD -Value 2
		set-itemproperty -path "$RegPath\Windows Error Reporting Queue Files" -name $RegPath -type DWORD -Value 2
		set-itemproperty -path "$RegPath\Windows Error Reporting System Archive Files" -name $RegPath -type DWORD -Value 2
		set-itemproperty -path "$RegPath\Windows Error Reporting System Queue Files" -name $RegPath -type DWORD -Value 2
		set-itemproperty -path "$RegPath\Windows ESD installation files" -name $RegPath -type DWORD -Value 2
		set-itemproperty -path "$RegPath\Windows Upgrade Log Files" -name $RegPath -type DWORD -Value 2
	}
	 
	cleanmgr /sagerun:$SageRun
	 
	do {
		"waiting for cleanmgr to complete..."
		start-sleep 5
	} while ((get-wmiobject win32_process | where-object {$_.processname -eq 'cleanmgr.exe'} | measure).count)
	 
	$FreespaceAfter = (Get-WmiObject win32_logicaldisk -filter "DeviceID='C:'" | select Freespace).FreeSpace/1GB

	"Free Space Before: {0}" -f $FreespaceBefore
	"Free Space After: {0}" -f $FreespaceAfter
}

Function Log-Message {

}


<#
@echo off
::TODO document this script!!!
::TODO convert to PowerShell 2.0 compatible and add verbose logging
::.Synopsis
::   Perorm a Windows 10 in-place upgrade
::.Description
::   Using Windows Setup Compatibility and custom logic, test if a Windows 10 in-place upgraded (Win7/8.1 to Win10 or
::      Win10 vXXXX to vYYYY) is likely to succeed.  If so, start the upgrade.
::      If not, attempt some basic remediation and retry
::      If automated remediation fails, log the results centrally for analysis
::   This script is designed to be executed manually or via any software distribution system including
::      SCCM/ConfigMgr, Altiris, LANDesk, Kace, PDQ Deploy, Active Directory Group Policy (GPO) startup script, etc., etc., etc.
::.PARAMETER
::   ScanOnly
::   Disable actual upgrade of Windows 10 and only perform a setup compatibility scan
::.EXAMPLE
::   Upgrade-Windows.cmd
::   Start full logic of perform upgrade scan, autoremediate, and upgrade if possible
::.EXAMPLE
::   Upgrade-Windows.cmd /ScanOnly
::   Start scan only logic of perform upgrade scan, autoremediate, and rescan
::.LINK
::   https://msdn.microsoft.com/windows/hardware/commercialize/manufacture/desktop/windows-setup-command-line-options
::   https://blogs.technet.microsoft.com/mniehaus/2015/08/23/windows-10-pre-upgrade-validation-using-setup-exe/
::   https://blogs.technet.microsoft.com/home_is_where_i_lay_my_head/2015/09/14/windows-10-setup-command-line-switches/
::   https://joshheffner.com/automate-windows-10-in-place-upgrades-from-the-command-line/#comment-3747
::   http://deploymentresearch.com/Research/Post/483/Windows-10-Setup-Technical-Drilldown
::   http://deploymentresearch.com/Research/Post/533/Improving-the-ConfigMgr-Inplace-Upgrade-Task-Sequence

setlocal EnableDelayedExpansion

:GetDate
for /F "usebackq tokens=1,2 delims==" %%i in (`wmic os get LocalDateTime /VALUE 2^>NUL`) do if '.%%i.'=='.LocalDateTime.' set ldt=%%j
set YYYYMMDD_HHMM=%ldt:~0,8%_%ldt:~8,4%


set _ThisPath=%~dp0
set _ThisPath=%_ThisPath:~,-1%
#>
Set-Variable -Name Thispath -Value !!!!!!!!!!!!!!!!!!!!!!!!!!
Set-Variable -Name LogShare -Value '\\APP-W1001-000.agency.OK.local\Logs$\Win10Setup'
Set-Variable -Name LogPath  -Value "$env:WinDir\Logs\Win10Setup"
Set-Variable -Name Upgrade  -Value $false

Set-Variable -Name ScanOptions -Value "/Auto Upgrade /Quiet /NoReboot /DynamicUpdate Disable /Compat ScanOnly /CopyLogs $LogPath"
Set-Variable -Name UpgradeOptions -Value "/Auto Upgrade /MigrateDrivers all /DynamicUpdate Disable /ShowOOBE none /Telemetry enable /CopyLogs $LogPath /PostOOBE $ThisPath /PostRollback $ThisPath"
#                  /Unattend:<answer_file>

#If Windows 10 drivers are prestaged then instruct Windows 10 setup to use them
If (Test-Path -Path "$env:SystemDrive\Drivers\Win10") {
   Set-Variable -Name UpgradeOptions -Value "$UpgradeOptions /InstallDrivers $env:SystemDrive\Drivers\Win10"
}
If (Test-Path -Path "$env:SystemDrive\Drivers\PGP") {
   Set-Variable -Name UpgradeOptions -Value "$UpgradeOptions /ReflectDrivers $env:SystemDrive\Drivers\PGP"
}

Write-Host "==============================================================================="
Write-Host "================== Upgrading Microsoft Windows to Windows 10 =================="
Write-Host "==============================================================================="
<#

:CMDoptions
If "%1"=="/ScanOnly" set _Upgrade=Skip
If "%1"=="ScanOnly" set _Upgrade=Skip

If %_Upgrade%==Skip Echo Running Windows 10 Setup in ScanOnly mode with scripted remediation.  An actual upgrade will not be performed.
Echo ScanOptions is %_ScanOptions%
Echo UpgradeOptions is %_UpgradeOptions%

REM remove existing Log files
If Exist %_LogPath%\Panther\setupact.log (
	Echo archiving previous log files
	"%~dp07za.exe" a -mx9 -t7z -r "%_LogPath%\..\Win10setup_%ComputerName%_%YYYYMMDD_HHMM%_existing.7z" "%_LogPath%\*.*"
	del /s /q %_LogPath%\*.*
)

REM run the upgrade in Scan Only mode
Echo Running Windows 10 Setup in ScanOnly mode
REM !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! start /wait SETUP.EXE %_ScanOptions%
REM !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! Set _ScanResult=%errorlevel%
Set _ScanResult=-1047526898
echo Scan Result code (_ScanResult) is %_ScanResult%
echo DEBUG check _ScanResult
If %_ScanResult%==-1047526898 (
    Echo _ScanResult returned 0xC190020E Insufficient free disk space
    REM Run Check Disk with auto repair
    REM Echo Running Check Disk with auto repair
    REM start /wait chkdsk.exe /f C:

REM	REM Delete System Restore Points
REM    Echo Deleting System Restore Points
REM    VSSAdmin.exe Delete Shadows /All /Quiet
REM
REM    REM use DISM to cleanup an image
REM    Echo Running DISM to cleanup an image
REM    DISM.exe /online /Cleanup-Image /scanhealth
REM    REM Windows 8+
REM    Echo Running DISM to cleanup Components and Reset Base
REM    DISM.exe /online /Cleanup-Image /StartComponentCleanup /ResetBase
REM    REM Windows 7
REM    Echo Running DISM to cleanup Service Packs
REM    DISM.exe /online /Cleanup-Image /spsuperseded
REM
REM    REM run Desktop Cleanup Manager
REM    Echo Running Desktop Cleanup Manager
REM    REM based on http://deploymentbunny.com/2014/06/05
REM    REM based on http://gregramsey.net/2014/05/14/automating-the-disk-cleanup-utility
REM    regedit /s %~d0\CleanMgr_SageSet.reg
REM    %WinDir%\system32\cleanmgr.exe /sagerun:1703

    REM delete known junk files
    Echo Deleting known junk files
REM    del /f /q /s %WinDir%\Memory.dmp
REM    del /f /q /s %WinDir%\minidump
    del /f /q /s %WinDir%\Temp\*.tmp
REM    del /f /q /s %WinDir%\Temp\*.log
REM    del /f /q /s %WinDir%\Temp\*.txt
REM    del /f /q /s %WinDir%\SoftwareDistribution\Download
REM    del /f /q /s %WinDir%\SoftwareDistribution\DataStore\Logs
REM    del /f /q    %WinDir%\SoftwareDistribution\DataStore\DataStore.edb
REM    del /f /q    %WinDir%\SoftwareDistribution\ReportingEvents.log
REM    del /f /q    %WinDir%\Logs\CBS\CbsPersist*.cab
REM    del /f /q    %WinDir%\Logs\CBS\CBS.log
    REM TODO add more

rem	REM compress specific folders
rem	Echo Compressing specific folders
rem	compact /c /s /i %WinDir%\Logs
rem	compact /c /s /i %WinDir%\Inf
rem	compact /c /s /i %WinDir%\Installer
)

Echo DEBUG rechecking scan results for rescan (_ScanResult is %_ScanResult%)
If %_ScanResult%==-1047526898 (
    Echo _ScanResult returned 0xC190020E Insufficient free disk space

	REM rerun the upgrade in Scan Only mode
	Echo removing last scan results
	del /s /q %_LogPath%\*.*

	Echo Rerunning Windows 10 Setup in ScanOnly mode
	Echo ScanOptions is %_ScanOptions%
REM !!!!!!!!!!	start /wait SETUP.EXE %_ScanOptions%
REM !!!!!!!!!!	Set _RescanResult=%errorlevel%
	Set _RescanResult=123456789
	echo Scan Result code (_RescanResult) is !_RescanResult!
)

REM Process Scan Result values and determine if the upgrade should continue
echo Upgrade is %_Upgrade% before processing scan results
If !_Upgrade!==Skip (
	echo Upgrading is being skipped due to command line parameter
) else (
	REM 0xC1900210 No issues found
	If !_RescanResult!==-1047526896 set _Upgrade=True
	If !_ScanResult!==-1047526896 set _Upgrade=True
	REM	-1047526904 / 0xC1900208 Compatibility issues found (hard block):
	REM	-1047526908 / 0xC1900204 Migration choice (auto upgrade) not available (probably the wrong SKU or architecture)
	REM	-1047526912 / 0xC1900200 Does not meet system requirements for Windows 10
	REM -1047526945 / 0xC19001DF Failed to get image information for C:\Install\Win10v1703_x64\Sources\Install.wim, image 1. Error: 0x80070070
	REM	More error codes: https://support.microsoft.com/en-us/help/10587/windows-10-get-help-with-upgrade-installation-errors
)
echo Upgrade is %_Upgrade% after processing scan results

REM if upgrade should continue, do it
If !_Upgrade!==True (
	Echo removing last scan results
	del /s /q %_LogPath%\*.*

	Echo Running Windows 10 Setup
	Echo with options of %_UpgradeOptions%
REM !!!!!!!!!!!!!!!!!	start /wait setup.exe %_UpgradeOptions%
	Set _UpgradeResult=%errorlevel%
	echo Upgrade Result code (_UpgradeResult) is %_UpgradeResult%

	REM 0x3 CONX_SETUP_EXITCODE_CONTINUE_REBOOT This upgrade was successful.
	If %_UpgradeResult%==0 set _Result=0
	If %_UpgradeResult%==3 set _Result=0
	If NOT %_Result%==0 set _Result=%_UpgradeResult%
	echo Upgrade interpreted Result code is %_Result%

	REM https://msdn.microsoft.com/windows/hardware/commercialize/manufacture/desktop/windows-setup-log-files-and-event-logs
	Echo Copying ETWProviders
	xcopy %~dp0sources\etwproviders C:\ProgramData\Windows\Setup\sources\ETWProviders\ /e /i /c
)


Echo archiving log files
"%~dp07za.exe" a -mx9 -t7z -r "%_LogPath%\..\Win10setup_%YYYYMMDD_HHMM%.7z" "%_LogPath%\*.*"
If EXIST "%_LogPath%\..\Win10setup_%YYYYMMDD_HHMM%.7z" del /s /q %_LogPath%\*.*

Echo copying log file archive to central share
copy "%_LogPath%\..\Win10setup_%YYYYMMDD_HHMM%.7z" "%_LogPath%\%_Result%_%ComputerName%_%YYYYMMDD_HHMM%.7z"
If %_Upgrade%==Skip (
	REM ScanOnly, upload log file archive to a central share
	If %_Result%==-1047526896 (
		REM Upgrade successful, upload log file archive to a central share
		xcopy "%_LogPath%\%_Result%_%ComputerName%_%YYYYMMDD_HHMM%.7z" %_LogShare%\_ScanOnly\Success
	) else (
		REM Upgrade not successful, upload log file archive to a central share
		xcopy "%_LogPath%\%_Result%_%ComputerName%_%YYYYMMDD_HHMM%.7z" %_LogShare%\_ScanOnly
	)
) else (
	If %_Result%==0 (
		REM Upgrade successful, upload log file archive to a central share
		xcopy "%_LogPath%\%_Result%_%ComputerName%_%YYYYMMDD_HHMM%.7z" %_LogShare%\_Success
	) else (
		REM Upgrade not successful, upload log file archive to a central share
		xcopy "%_LogPath%\%_Result%_%ComputerName%_%YYYYMMDD_HHMM%.7z" %_LogShare%
	)
)
del /q "%_LogPath%\%_Result%_%ComputerName%_%YYYYMMDD_HHMM%.7z"


echo Exiting with return code %_Result%
Exit /b %_Result%
:eof

#>