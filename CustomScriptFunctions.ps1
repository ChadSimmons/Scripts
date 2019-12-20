##requires -Version 2
##Set-StrictMode -Version Latest #i.e. Option Explicit (all variables must be declared)
################################################################################
# Latest Update	- 2018/01/31
#.SYNOPSIS
#   CustomScriptFunctions.ps1
#   Function Library for Custom Scripting generally with ConfigMgr/SCCM and related activities
#.DESCRIPTION
#	Custom Exit Code Ranges:
#	- 60000 - 68999: Reserved for built-in exit codes in the script toolkit
#	- 69000 - 69999: Recommended for user customized exit codes in invoking script
#   A set of functions for custom scripts including
#   - logging (CMTrace and Windows Event Log)
#   - common variables (ScriptInfo, etc.)
#   - common functions (read/write registry keys, compress files/folders)
#   - and more
#   ===== Defined Functions =====
#   - PowerShell approved Verbs https://msdn.microsoft.com/en-us/library/windows/desktop/ms714428(v=vs.85).aspx
#     New/Set, Find/Search, Get/Read, Invoke/Start, test, connect, read, write, Compress/Expand, Initialize
#	- Get-CurrentLineNumber
#	- Get-currentFunctionName
#	- Get-ScriptInfo
#	- Write-LogMessage
#	- Backup-LogFile
#	- Start-Script
#	- Stop-Script
#	- Send-SCCMStatusMessages
#	- Write-SCCMStatusMessage
#	- Get-ENVPathFolders
#	- Connect-ConfigMgr
#	- Update-SCCMObjectSecurityScopes
#   ===== Defined Variables =====
#	- $ScriptInfo.FullPath			# Path and File name of the invoking script
#	- $ScriptInfo.Path				# Path of the invoking script
#	- $ScriptInfo.Name				# Name and extension of the invoking script
#	- $ScriptInfo.BaseName			# Name without extension of the invoking script
#	- $ScriptInfo.LogPath			# Path for Custom Scripting log files
#	- $ScriptInfo.LogFile			# Path and File name for Custom Scripting log file
#	- $ScriptInfo.LogFullPath		# alias of LogFile
#	- $ScriptInfo.LibraryFullPath	# Path and File name of the function library (this file)
#	- $ScriptInfo.StartTime			# Script Start Time
#	- $ScriptInfo.EndTime			# Script End Time
#	- $ScriptInfo.PowerShellVersion	# Version of PowerShell which is running
#	- $ScriptInfo.TimezoneBias		# Time Zone Bias formatted like '-360'
#	- TODO: global:csLogFileCommon	# File for recording milestone events from this script to consolidated file
#   - TODO: global:csLogEventLog    #
#   - TODO: global:csLogEventSource	#
#.Functionality
#   This module / script should be imported / dot-sourced at the beginning of a script
#.PARAMETER ScriptFullPath
#   Specifies the full path/folder/directory, name, and extension of the script library (this file)
#.EXAMPLE
#   . .\CustomScriptFunctions.ps1 -ScriptFullPath 'C:\Scripts\CustomScriptFunctions.psm1'
#   dot-sourcing the script functions/module and specifying the full script path.
#.LINK
#   This script is maintained at https://github.com/ChadSimmons/Scripts
#.NOTES
#   Additional information about the function or script.
#   ========== Keywords ==========
#   Keywords: Custom Scripting Functions Module
#   ========== Change Log History ==========
#   - 2017/12/27 by Chad.Simmons@CatapultSystems.com - Created
#   - 2017/12/27 by Chad@ChadsTech.net - Created
#   ========== Additional References and Reading ==========
#   - based loosely on the PowerShell Application Deployment Toolkit: http://psappdeploytoolkit.com
#   - based loosely on Mick Pletcher's PowerShell Deployment Module: http://mickitblog.blogspot.com/2014/12/powershell-deployment-module.html
#   === To Do / Proposed Changes ===
#   - TODO: Convert to a PowerShell script module
#         - http://mikefrobbins.com/2013/07/04/how-to-create-powershell-script-modules-and-module-manifests/
#         - https://msdn.microsoft.com/en-us/library/dd878310%28v=vs.85%29.aspx
#         - Example: https://gallery.technet.microsoft.com/scriptcenter/Multithreaded-PowerShell-0bc3f59b
#	- TODO: Migrate all functionality from Chad Simmons' CustomScripting.ps1
#	- TODO: Migrate desired functionality from PowerShell Community Extensions https://github.com/Pscx
#	- TODO: Migrate desired functionality from Mick Pletcher's PowerShell Deployment Module http://mickitblog.blogspot.com/2014/12/powershell-deployment-module.html
#			Function Copy-File {}
#			Function Copy-Files {}
#			Function New-Folder {}
#			Function New-FileShortcut -StartMenu|-Taskbar|-Path
#			Function New-URLShortcut
#			Function Remove-File {}
#			Function Remove-Folder {}
#			Function Remove-FolderFromUserProfiles
#			Function Remove-RegistryKey -HKU|-HKLM
#			Function Remove-FileShortcut -StartMenu|-Taskbar|-Path
#			Function Set-WindowsFeature -Enable|-Disable
#			Function Set-FolderPermissions
#			Function Start-Process -Wait|-NoWait
#			Function Stop-Process -Wait|-NoWait
#			Function Wait-ProcessEnd -Timeout
#			Function Install-EXE {}
#			Function Install-MSI {}
#			Function Install-MSP {}
#			Function Install-MSU {}
#			Function Install-Fonts {}
#			Function Uninstall-MSI {} -ByName|-ByGUID|-byFile
#			Function Uninstall-MSU {}
#	- TODO: Migrate desired functionality from PowerShell Application Deployment Toolkit http://psappdeploytoolkit.com
#			non-functionalized info and logic
#			Function Write-FunctionHeaderOrFooter
#			Function New-ZipFile
#			Function Extract-Zipfile
#			Function Exit-Script
#			Function Resolve-Error
#			Function Get-FreeDiskSpace
#			Function Get-InstalledApplication
#			Function Execute-MSI
#			Function Remove-MSIApplications
#			Function Execute-Process
#			Function Get-MsiExitCodeMessage
#			Function New-Folder
#			Function Copy-File
#			Function Remove-File
#			Function Convert-RegistryPath
#			Function Test-RegistryValue
#			Function Get-RegistryKey
#			Function Set-RegistryKey
#			Function Remove-RegistryKey
#			Function Invoke-HKCURegistrySettingsForAllUsers
#			Function Get-UserProfiles
#			Function Get-FileVersion
#			Function New-Shortcut
#			Function Refresh-Desktop
#			Function Refresh-SessionEnvironmentVariables
#			Function Get-ScheduledTask
#			Function Get-RunningProcesses
#			Function Set-PinnedApplication
#			Function Get-IniValue
#			Function Set-IniValue
#			Function Invoke-RegisterOrUnregisterDLL
#			Function Test-MSUpdates
#			Function Install-MSUpdates
#			Function Invoke-SCCMTask
#			Function Install-SCCMSoftwareUpdates
#			Function Update-GroupPolicy
#			Function Set-ActiveSetup
#			Function Test-ServiceExists
#			Function Stop-ServiceAndDependencies
#			Function Start-ServiceAndDependencies
#			Function Get-ServiceStartMode
#			Function Set-ServiceStartMode
#			Function Get-LoggedOnUser
#			Function Get-PendingReboot
################################################################################
#region    ######################### Parameters and variable initialization ####
	[CmdletBinding()] #(SupportsShouldProcess=$false, ConfirmImpact="Low")
	Param (
		[Parameter()][string]$ScriptFullPath
	)
#endregion ######################### Parameters and variable initialization ####


#region    ######################### Functions #################################
################################################################################
################################################################################
Function Get-CurrentLineNumber {
	If ($psISE) {
		$script:CurrentLine = $psISE.CurrentFile.Editor.CaretLine
	} else { $script:CurrentLine = $MyInvocation.ScriptLineNumber }
	return $script:CurrentLine
}
Function Get-CurrentFunctionName {
	return (Get-Variable MyInvocation -Scope 1).Value.MyCommand.Name
}
Function Get-ScriptInfo ($FullPath) {
	#.Synopsis
	#   Get the name and path of the script file
	#.Description
	#   Sets global variables for ScriptStartTime, ScriptNameAndPath, ScriptPath, ScriptName, ScriptBaseName, and ScriptLog
	#   This function works inline or in a dot-sourced script
	#   See snippet Get-ScriptInfo.ps1 for excruciating details and alternatives
	Write-Verbose -Message "Called Function $(Get-CurrentFunctionName) -FullPath [$FullPath]"
	If (Test-Path variable:Global:ScriptInfo) {
		Write-Verbose 'ScriptInfo already set.  Resetting Times'
		$ScriptInfo.StartTime = $(Get-Date)
		$ScriptInfo.EndTime = $null
	} ElseIf ($ScriptInfo -is [object]) {
		Write-Verbose 'ScriptInfo already set.  Resetting Times'
		$ScriptInfo.StartTime = $(Get-Date)
		$ScriptInfo.EndTime = $null
	} Else {
		$Global:ScriptInfo = New-Object -TypeName PSObject
		Add-Member -InputObject $Global:ScriptInfo -MemberType NoteProperty -Name 'StartTime' -Value $(Get-Date) #-Description 'The date and time the script started'
		Add-Member -InputObject $Global:ScriptInfo -MemberType NoteProperty -Name 'EndTime' -Value $Null #-Description 'The date and time the script completed'

		If ([string]::IsNullorEmpty($FullPath) -or (-not(Test-Path -Path $FullPath))) {
			#The ScriptNameAndPath was not passed, thus detect it
			If ($psISE) {
				Add-Member -InputObject $Global:ScriptInfo -MemberType NoteProperty -Name 'FullPath' -Value $psISE.CurrentFile.FullPath #-Description 'The full path/folder/directory, name, and extension script file'
				Write-Verbose "Invoked ScriptPath from dot-sourced Script Function: $($ScriptInfo.FullPath)"
			} ElseIf ($((Get-Variable MyInvocation -Scope 1).Value.InvocationName) -eq '.') {
				#this script has been dot-sourced... https://stackoverflow.com/questions/4875912/determine-if-powershell-script-has-been-dot-sourced
				Add-Member -InputObject $Global:ScriptInfo -MemberType NoteProperty -Name 'FullPath' -Value (Get-Variable MyInvocation -Scope 1).Value.ScriptName #-Description 'The full path/folder/directory, name, and extension script file'
				Write-Verbose "Invoked ScriptPath from dot-sourced Script Function: $($ScriptInfo.FullPath)"
			} Else {
				Add-Member -InputObject $Global:ScriptInfo -MemberType NoteProperty -Name 'FullPath' -Value $script:MyInvocation.MyCommand.Path #-Description 'The full path/folder/directory, name, and extension script file'
				Write-Verbose "Invoked ScriptPath from Invoked Script Function: $($ScriptInfo.FullPath)"
			}
		} else {
			Add-Member -InputObject $Global:ScriptInfo -MemberType NoteProperty -Name 'FullPath' -Value $FullPath #-Description 'The full path/folder/directory, name, and extension script file'
		}
		#Get Timezone if not already defined #from Utility.ps1 by Duane.Gardiner@1e.com version 2.0 modified  2014/04/02
		[string]$local:TimezoneBias = [System.TimeZoneInfo]::Local.GetUtcOffset((Get-Date)).TotalMinutes
		If ( $local:TimezoneBias -match "^-" ) {
			$local:TimezoneBias = $local:TimezoneBias.Replace('-', '+') # flip the offset value from negative to positive
		} else {
			$local:TimezoneBias = '-' + $local:TimezoneBias
		}
		Add-Member -InputObject $Global:ScriptInfo -MemberType NoteProperty -Name 'Path' -Value $(Split-Path -Path $ScriptInfo.FullPath -Parent) #-Description 'The path/folder/directory containing the script file'
		Add-Member -InputObject $Global:ScriptInfo -MemberType NoteProperty -Name 'Name' -Value $(Split-Path -Path $ScriptInfo.FullPath -Leaf) #-Description 'The name and extension of the script file'
		Add-Member -InputObject $Global:ScriptInfo -MemberType NoteProperty -Name 'BaseName' -Value $([System.IO.Path]::GetFileNameWithoutExtension($ScriptInfo.Name)) #-Description 'The name without the extension of the script file'
		Add-Member -InputObject $Global:ScriptInfo -MemberType NoteProperty -Name 'LogPath' -Value $($ScriptInfo.Path) #-Description 'The full path/folder/directory, name, and extension script file with log extension'
		Add-Member -InputObject $Global:ScriptInfo -MemberType NoteProperty -Name 'LogFile' -Value $($ScriptInfo.Path + '\' + $ScriptInfo.BaseName + '.log') #-Description 'The full path/folder/directory, name, and extension script file with log extension'
		Add-Member -InputObject $Global:ScriptInfo -MemberType NoteProperty -Name 'LogFullPath' -Value $ScriptInfo.LogFile #-Description 'The full path/folder/directory, name, and extension script file with log extension'
		Add-Member -InputObject $Global:ScriptInfo -MemberType NoteProperty -Name 'LibraryFullPath' -Value $FunctionLibrary #-Description 'The full path/folder/directory, name, and extension of the script library (this file)'
		Add-Member -InputObject $Global:ScriptInfo -MemberType NoteProperty -Name 'PowerShellVersion' -Value $($PSversionTable.PSversion.toString())
		Add-Member -InputObject $Global:ScriptInfo -MemberType NoteProperty -Name 'TimezoneBias' -Value $TimezoneBias
	}
}
Function Write-LogMessage {
	#.Synopsis Write a log entry in CMtrace format
	#.Notes
	#	CMTrace time must be formatted as HH:mm:ss.fff-### to support both CMTrace.exe and Configuration Manager Support Center Log Viewer
	#.Example  Write-LogMessage -LogFile $LogFile
	#.Example  Write-LogMessage -Message "This is a normal message" -LogFile $LogFile -Console
	#.Example  Write-LogMessage -Message "This is a normal message" -ErrorMessage $Error -LogFile $LogFile -Console
	#.Example  Write-LogMessage -Message "This is a warning" -Type Warn -Component "Test Component" -LogFile $LogFile
	#.Example  Write-LogMessage -Message "This is an Error!" -Type Error -Component "My Component" -LogFile $LogFile
	#.Parameter Message
	#	The message to write
	#.Parameter Type
	#	The type of message Information/Info/1, Warning/Warn/2, Error/3
	#.Parameter Component
	#	The source of the message being logged.  Typically the script name or function name.
	#.Parameter LogFile
	#	The file the message will be logged to
	#.Parameter LogType
	#	The logging type consisting of one or more of CMTrace, CSV, TSV, WindowsEvent
	#.Parameter Console
	#	Display the Message in the console
	Param (
		[Parameter(Mandatory = $true)][string]$Message,
		[Parameter()][ValidateSet('Error', 'Warn', 'Warning', 'Info', 'Information', '1', '2', '3')][string]$Type,
		[Parameter()][string]$Component = $ScriptInfo.BaseName,
		[Parameter()][string]$LogFile = $ScriptInfo.LogFile,
		[Parameter()][string[]]$LogType = 'CMTrace', # @('CMTrace','CSV','TSV','WinEvent')
		[Parameter()][switch]$Console
	)
	#Write-Verbose -Message "Called Function $(Get-CurrentFunctionName)"
	If ($LogFile.Length -lt 6) {$LogFile = "$env:WinDir\Logs\Script.log"} #Must not be null
	If ([string]::IsNullOrEmpty($Component)) {$Component = ' '} #Must not be null
	If ([string]::IsNullOrEmpty($Message)) {$Message = '<blank>'} #Must not be null
	Switch ($Type) {
		{ @('3', 'Error', 'Err') -contains $_ } { $intType = 3; $Type = 'Error' } #3 = Error (red)
		{ @('2', 'Warn', 'Warning') -contains $_ } { $intType = 2; $Type = 'Warning' } #2 = Warning (yellow)
		Default { $intType = 1; $Type = 'Information' } #1 = Normal
	}
	If ($Console) {
		#write to console if enabled
		Switch ($Type) {
			'Information' { Write-Output $Message }
			'Warning' { Write-Warning $Message }
			'Error' { Write-Error $Message }
		}
	} else {
		Write-Verbose -Message "Write-LogMessage: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`t$env:ComputerName `t$Type `t$Component `n   $Message"
	}
	#write message
	If ('CMTrace' -contains $LogType) {
		try {
			"<![LOG[$Message]LOG]!><time=`"$(Get-Date -Format HH:mm:ss.fff)$($ScriptInfo.TimezoneBias)`" date=`"$(Get-Date -Format "MM-dd-yyyy")`" component=`"$Component`" context=`"`" type=`"$intType`" thread=`"$PID`" file=`"$Component`">" | Out-File -Append -Encoding UTF8 -FilePath $LogFile
		} catch { Write-Error "Failed to write to the CMTrace style log file [$LogFile]" }
	}
	If ('CSV' -contains $LogType) {
		try {
			$CSVLogFile = (Split-Path -Path $LogFile -Parent) + '\' + $([System.IO.Path]::GetFileNameWithoutExtension($LogFile)) + '.csv'
			@($(Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $env:ComputerName, $Type, $Component, $Message) -join "`," | Out-File -Append -Encoding UTF8 -FilePath $CSVLogFile #PowerShell 2.0 version
			#Export-Csv -Path "$CSVLogFile" -NoTypeInformation -Delimiter "`t" -InputObject @($(Get-Date -Format 'yyyy-MM-dd HH:mm:ss'),$env:ComputerName,$Type,$Component,$Message) #PowerShell 3.0+ version
		} catch { Write-Error "Failed to write to the CSV style log file [$CSVLogFile]" }
	}
	If ('TSV' -contains $LogType) {
		try {
			$TSVLogFile = (Split-Path -Path $LogFile -Parent) + '\' + $([System.IO.Path]::GetFileNameWithoutExtension($LogFile)) + '.tsv'
			@($(Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $env:ComputerName, $Type, $Component, $Message) -join "`t" | Out-File -Append -Encoding UTF8 -FilePath $TSVLogFile #PowerShell 2.0 version
			#Export-Csv -Path "$CSVLogFile" -NoTypeInformation -Delimiter "`t" -InputObject @($(Get-Date -Format 'yyyy-MM-dd HH:mm:ss'),$env:ComputerName,$Type,$Component,$Message) #PowerShell 3.0+ version
		} catch { Write-Error "Failed to write to the CSV style log file [$CSVLogFile]" }
	}
	If ('WinEvent' -contains $LogType) {
		try {
			Write-EventLog -LogName 'Application' -Source 'WSH' -EntryType $Type -EventId $intType -Message "$Message"
		} catch { Write-Error "Failed to write to the Windows Event log [Application]" }
	}
}
Function Backup-LogFile {
	#.Synopsis
	#	Archive the log file if the size is beyond a threshold
	#.Parameter LogFile
	#	The file the message will be logged to
	#.Parameter LogFileMaxSizeMB
	#	Maximum file size limit for log file in megabytes (MB). Default is 2 MB.
	#.Example   Backup-LogFile
	#.Example   Backup-LogFile -LogFile "$env:WinDir\Logs\Scripts\CustomScripts.log" -LogFileMaxSizeMB = 0.2
	Param (
		[Parameter()][ValidateNotNullorEmpty()][string]$LogFile = $($ScriptInfo.LogFile),
		[Parameter()][ValidateRange(0.1, 100)][decimal]$LogFileMaxSizeMB = 2
	)
	Write-Verbose -Message "Called Function $(Get-CurrentFunctionName)"
	<# debug code
		[string]$LogFile = "$env:WinDir\Logs\Scripts.log"
		[decimal]$LogFileMaxSizeMB = 0.005
	#>
	## Archive log file if size is greater than $LogFileMaxSizeMB
	If (Test-Path -Path $LogFile) {
		Try {
			If (((Get-ItemProperty -Path $LogFile).Length / 1MB) -gt $LogFileMaxSizeMB) {
				## Change the file extension from '.log' to 'YYYYMMddHHmmss.log'
				[string]$LogFileArchive = [IO.Path]::ChangeExtension($LogFile, $(Get-Date -Format 'yyyyMMddHHmmss') + '.log')
				## Log message about archiving the log file
				Write-LogMessage -Message "Maximum log file size [$LogFileMaxSizeMB MB] reached. Renaming log file to [$LogFileArchive]." -Component 'SYSTEM' -Type 'Info'
				## Archive existing log file from <filename>.log to <filename>.yyyyMMddHHmmss.log. Overwrites any existing file.
				Move-Item -LiteralPath $LogFile -Destination $LogFileArchive -Force -ErrorAction 'Stop'
				## Start new log file and Log message about archiving the old log file
				Write-LogMessage -Message "Previous log file was renamed to [$LogFileArchive] because maximum log file size of [$LogFileMaxSizeMB MB] was reached." -Component 'SYSTEM' -Type 'Info'
			}
		} Catch {
			## If renaming of file fails, script will continue writing to log file even if size goes over the max file size
			$Message = "Failed to rename file [$LogFile] to [$LogFileArchive] after the maximum log file size of [$LogFileMaxSizeMB MB] reached."
			Write-LogMessage -Message $Message -Component 'SYSTEM' -Type 'Error'
			Write-Warning -Message $Message
		}
	}
}
Function Start-Script ($LogFile) {
	#Required: Get-ScriptInfo(), Write-LogMessage()
	#if the ScriptLog is undefined set to global ScriptLog
	#if the ScriptLog is still undefined set to <WindowsDir>\Logs\Script.log
	Write-Verbose -Message "Called Function $(Get-CurrentFunctionName) -LogFile [$LogFile]"
	If (-not($ScriptInfo -is [object])) {
		Get-ScriptInfo -FullPath $(If (Test-Path -LiteralPath 'variable:HostInvocation') { $HostInvocation.MyCommand.Definition } Else { $MyInvocation.MyCommand.Definition })
	}
	If ([string]::IsNullOrEmpty($LogFile)) {
		If ([string]::IsNullOrEmpty($ScriptInfo.LogFile)) {
			$ScriptInfo.LogFile = "$env:WinDir\Logs\Scripts.log"
			$ScriptInfo.LogFullPath = "$env:WinDir\Logs\Scripts.log"
		}
	} else {
		$ScriptInfo.LogFile = $LogFile
		$ScriptInfo.LogFullPath = $LogFile
	}
	$ScriptInfo.LogPath = Split-Path -Path $LogFile -Parent
	#if the LogFile folder does not exist, create the folder
	If (-not(Test-Path $ScriptInfo.LogPath)) { New-Item -Path $ScriptInfo.LogPath -ItemType Directory -Force}
	#write initial message
	Backup-LogFile -LogFile $($ScriptInfo.LogFile)
	Write-LogMessage -Message "==================== SCRIPT START ===================="
	Write-Verbose "Logging to $($ScriptInfo.LogFile)"
}
Function Stop-Script ($ReturnCode) {
	#Required: Get-ScriptInfo(), Write-LogMessage()
	Write-Verbose -Message "Called Function $(Get-CurrentFunctionName) -ReturnCode [$ReturnCode]"
	Write-LogMessage -Message "Exiting with return code $ReturnCode"
	$ScriptInfo.EndTime = $(Get-Date) #-Description 'The date and time the script completed'
	$ScriptTimeSpan = New-TimeSpan -Start $ScriptInfo.StartTime -End $ScriptInfo.EndTime #New-TimeSpan -seconds $(($(Get-Date)-$StartTime).TotalSeconds)
	Write-LogMessage -Message "Script Completed in $([math]::Round($ScriptTimeSpan.TotalSeconds)) seconds, started at $(Get-Date $ScriptInfo.StartTime -Format 'yyyy/MM/dd hh:mm:ss'), and ended at $(Get-Date $ScriptInfo.EndTime -Format 'yyyy/MM/dd hh:mm:ss')" -Console
	Write-Verbose -Message $('ScriptInfo Custom PSObject...' + $($ScriptInfo | Format-List | Out-String))
	Write-LogMessage -Message "==================== SCRIPT COMPLETE ===================="
	Exit $ReturnCode
}
Function Send-SCCMStatusMessages {
	#.Synopsis
	#	Instruct the ConfigMgr/SCCM client to send all queued State and Status messages
	#.Notes
	#	- TODO: Test
	#   ========== Additional References and Reading ==========
	#	Status Messages https://gallery.technet.microsoft.com/scriptcenter/Script-for-launching-cc658190
	#	StateMessages https://blogs.technet.microsoft.com/charlesa_us/2015/03/07/triggering-configmgr-client-actions-with-wmic-without-pesky-right-click-tools/
	#		{00000000 - 0000 - 0000 - 0000 - 000000000111} Send Unsent State Message
	#	Invoke-WMIMethod -Namespace root\ccm -Class SMS_CLIENT -Name TriggerSchedule "{00000000-0000-0000-0000-000000000###}"
	#	WMIC /namespace:\\root\ccm path sms_client CALL TriggerSchedule "{00000000-0000-0000-0000-000000000###}" /NOINTERACTIVE
	Try {
		Write-Verbose "Sending ConfigMgr Pending State and Status Messages"
		Invoke-WMIMethod -Namespace 'root\ccm' -Class 'SMS_CLIENT' -Name TriggerSchedule "{00000000-0000-0000-0000-000000000111}"
		Write-LogMessage -Message "Sent ConfigMgr Pending State Messages" -Type Info
		Try {
			$SCCMmsg = New-Object -ComObject Microsoft.SMS.Event    #CCM Client COM object to send status message to use with Status Message Filter Rules
			$SCCMmsg.SubmitPending()
			Write-LogMessage -Message "Sent ConfigMgr Pending Status Messages" -Type Info
		} Catch {
			Write-LogMessage -Message "Failed Sending ConfigMgr Pending Status Messages" -Type Warn
		}
	} Catch {
		Write-LogMessage -Message "Failed Sending ConfigMgr Pending State Messages" -Type Warn
	}
	Remove-Variable SCCMMsg -ErrorAction SilentlyContinue
}
Function Write-SCCMStatusMessage {
	#.Synopsis
	#	Instruct the ConfigMgr/SCCM client to send a custom Status message
	#.Notes
	#	- TODO: Test
	#   ========== Additional References and Reading ==========
	#.Link
	#	based on https://gallery.technet.microsoft.com/scriptcenter/Script-for-launching-cc658190
	Param (
		[Parameter(Mandatory=$true)][string]$String1,
		$String2, $String3, $String4, $String5, $String6, $String7, $String8, $String9, $String10
	)
	Write-Verbose "Sending Custom/Generic ConfigMgr Status Message..."
	Try {
		$SCCMMsg = New-Object -ComObject Microsoft.SMS.Event
		$SCCMMsg.EventType ="SMS_GenericStatusMessage_Info"
		$SCCMMsg.SetProperty("InsertionString1", "$String1")
		If (-not([string]::IsNullOrEmpty($String2)))  { $SCCMMsg.SetProperty("InsertionString2", "$String2") }
		If (-not([string]::IsNullOrEmpty($String3)))  { $SCCMMsg.SetProperty("InsertionString3", "$String3") }
		If (-not([string]::IsNullOrEmpty($String4)))  { $SCCMMsg.SetProperty("InsertionString4", "$String4") }
		If (-not([string]::IsNullOrEmpty($String5)))  { $SCCMMsg.SetProperty("InsertionString5", "$String5") }
		If (-not([string]::IsNullOrEmpty($String6)))  { $SCCMMsg.SetProperty("InsertionString6", "$String6") }
		If (-not([string]::IsNullOrEmpty($String7)))  { $SCCMMsg.SetProperty("InsertionString7", "$String7") }
		If (-not([string]::IsNullOrEmpty($String8)))  { $SCCMMsg.SetProperty("InsertionString8", "$String8") }
		If (-not([string]::IsNullOrEmpty($String9)))  { $SCCMMsg.SetProperty("InsertionString9", "$String9") }
		If (-not([string]::IsNullOrEmpty($String10))) { $SCCMMsg.SetProperty("InsertionString10", "$String10") }
		$SCCMMsg.SubmitPending()
		Write-LogMessage -Message "Sent Custom/Generic ConfigMgr Status Message [$String1]" -Type Info
	} Catch {
		Write-LogMessage -Message "Failed sending Custom/Generic ConfigMgr Status Message [$String1]" -Type Warning
	}
	Remove-Variable SCCMMsg -ErrorAction SilentlyContinue
}
Function Get-ENVPathFolders {
	#.Synopsis Split $env:Path into an array
	#.Notes
	#  - Handle 1) folders ending in a backslash 2) double-quoted folders 3) folders with semicolons 4) folders with spaces 5) double-semicolons i.e. blanks
	#  - Example path: 'C:\WINDOWS\;"C:\Path with semicolon; in the middle";"E:\Path with semicolon at the end;";;C:\Program Files;'
	#  - 2018/01/30 by Chad@ChadsTech.net - Created
	$PathArray = @()
	$env:Path.ToString().TrimEnd(';') -split '(?=["])' | ForEach-Object { #remove a trailing semicolon from the path then split it into an array using a double-quote as the delimiter keeping the delimiter
		If ($_ -eq '";') {
			# throw away a blank line
		} ElseIf ($_.ToString().StartsWith('";')) {
			# if line starts with "; remove the "; and any trailing backslash
			$PathArray += ($_.ToString().TrimStart('";')).TrimEnd('\')
		} ElseIf ($_.ToString().StartsWith('"')) {
			# if line starts with " remove the " and any trailing backslash
			$PathArray += ($_.ToString().TrimStart('"')).TrimEnd('\') #$_ + '"'
		} Else {
			# split by semicolon and remove any trailing backslash
			$_.ToString().Split(';') | ForEach-Object { If ($_.Length -gt 0) { $PathArray += $_.TrimEnd('\') } }
		}
	}
	Return $PathArray
}
Function Connect-ConfigMgr {
	#.Synopsis
	#   Load Configuration Manager PowerShell Module
	#.Description
	#   if SiteCode is not specified, detect it
	#   if SiteServer is not specified, use the computer from PSDrive if it exists, otherwise use the current computer
	#.Link
	#   http://blogs.technet.com/b/configmgrdogs/archive/2015/01/05/powershell-ise-add-on-to-connect-to-configmgr-connect-configmgr.aspx
	Param (
		[Parameter(Mandatory = $false)][ValidateLength(3, 3)][string]$SiteCode,
		[Parameter(Mandatory = $false)][ValidateLength(1, 255)][string]$SiteServer
	)
	If ($null -ne $Env:SMS_ADMIN_UI_PATH) {
		#import the module if it exists
		If ($null -eq (Get-Module ConfigurationManager)) {
			Write-Verbose 'Importing ConfigMgr PowerShell Module...'
			$TempVerbosePreference = $VerbosePreference
			$VerbosePreference = 'SilentlyContinue'
			try {
				##Alternate method by https://kelleymd.wordpress.com/2015/03/26/powershell-module-reference-and-auto-load
				#<!remove the underscores!>R_e_q_u_i_r_e_s –Modules "$($ENV:SMS_ADMIN_UI_PATH)\..\ConfigurationManager.psd1"
				#get-help Get-CMSite
				Import-Module "$($ENV:SMS_ADMIN_UI_PATH)\..\ConfigurationManager.psd1"
			} catch {
				Write-Error 'Failed Importing ConfigMgr PowerShell Module.'
				Throw $_
			}
			$VerbosePreference = $TempVerbosePreference
			Remove-Variable TempVerbosePreference
		} else {
			Write-Verbose "The ConfigMgr PowerShell Module is already loaded."
		}
		# If SiteCode was not specified detect it
		If ([string]::IsNullOrEmpty($SiteCode)) {
			try {
				$SiteCode = (Get-PSDrive -PSProvider -ErrorAction Stop CMSITE).Name
			} catch {
				Throw $_
			}
		}
		# Connect to the site's drive if it is not already present
		if ($null -eq (Get-PSDrive -Name $SiteCode -PSProvider CMSite -ErrorAction SilentlyContinue)) {
			Write-Verbose -Message "Creating ConfigMgr Site Drive $($SiteCode):\ on server $SiteServer"
			# If SiteCode was not specified use the current computer
			If ([string]::IsNullOrEmpty($SiteServer)) {
				$SiteServer = $env:ComputerName
			}
			try {
				New-PSDrive -Name $SiteCode -PSProvider CMSite -Root $SiteServer -Scope Global #-Persist
			} catch {
				Throw $_
			}
		}
		#change location to the ConfigMgr Site
		try {
			Push-Location "$($SiteCode):\"
			Pop-Location
		} catch {
			Write-Error "Error connecting to the ConfigMgr site"
			Throw $_
		}
	} else {
		Throw "The ConfigMgr PowerShell Module does not exist!  Install the ConfigMgr Admin Console first."
	}
}; Set-Alias -Name 'Connect-CMSite' -Value 'Connect-ConfigMgr' -Description 'Load the ConfigMgr PowerShell Module and connect to a ConfigMgr site'
Function Update-SCCMObjectSecurityScopes {
	#.Synopsis
	#	Add and Remove Security Scopes from an array of ConfigMgr objects
	#.Notes
	#   === To Do / Proposed Changes ===
	#	- TODO: add error handling
	param (
		[Parameter(Mandatory=$true)]$ObjectID,
		[Parameter(Mandatory=$true)][string]$ObjectType,
		[Parameter(Mandatory=$false)][string]$AddScopeName,
		[Parameter(Mandatory=$false)][string]$RemoveScopeName,
		[Parameter(Mandatory=$true)][string]$SiteCode
	)
	Begin {
		Connect-ConfigMgr
		Push-Location "$SiteCode`:\"
		$AddScope = Get-CMSecurityScope -Name $AddScopeName
		$RemoveScope = Get-CMSecurityScope -Name $RemoveScopeName
		Pop-Location
	}
	Process {
		ForEach ($ObjectIDInstance in $ObjectID) {
			Switch ($ObjectType) {
				'Application' {
					Push-Location "$SiteCode`:\"
					$CMObject = Get-CMApplication -Id $ObjectIDInstance
					Pop-Location
					Write-LogMessage -Message "Verifying Application CI_ID [$($CMObject.CI_ID)] named [$($CMObject.LocalizedDisplayName)]"
				}
				'Package' {
					Push-Location "$SiteCode`:\"
					$CMObject = Get-CMPackage -Id $ObjectIDInstance
					Pop-Location
					Write-LogMessage -Message "Verifying Package ID [$($CMObject.PackageID)] named [$($CMObject.Name)]"
				}
				'TaskSequence' {
					Push-Location "$SiteCode`:\"
					$CMObject = Get-CMApplication -Id $ObjectIDInstance
					Pop-Location
					Write-LogMessage -Message "Verifying TaskSequence ID [$($CMObject.PackageID)] named [$($CMObject.Name)]"
				}
			}
			Push-Location "$SiteCode`:\"
			$CMObjectScopes = Get-CMObjectSecurityScope -InputObject $CMObject
			Pop-Location
			Write-LogMessage -Message "[$ObjectType] Object ID [$ObjectIDInstance] has [$($CMObjectScopes.Count)] scopes assigned"
			If ($CMObjectScopes.CategoryID -notcontains $AddScope.CategoryID) {
				#Add the production Security Scope if it isn't already added
				Write-LogMessage -Message "Adding scope [$AddScopeName] to [$ObjectType] Object ID [$ObjectIDInstance]"
				Push-Location "$SiteCode`:\"
				Add-CMObjectSecurityScope -InputObject $CMObject -Scope $AddScope -Confirm:$false -Force
				Pop-Location
			}
			If ($CMObjectScopes.CategoryID -contains $RemoveScope.CategoryID) {
				#Remove the lab Security Scope if it is added
				Write-LogMessage -Message "Removing scope [$RemoveScopeName] from [$ObjectType] Object ID [$ObjectIDInstance]"
				Push-Location "$SiteCode`:\"
				Remove-CMObjectSecurityScope -InputObject $CMObject -Scope $RemoveScope -Confirm:$false -Force
				Pop-Location
			}
			#Set-CMObjectSecurityScope -InputObject $CMPackage -Action AddMembership -Name 'Stores-Production'
			#Set-CMObjectSecurityScope -InputObject $CMPackage -Action RemoveMembership -Name 'Stores-TCoE Lab'
			#Add-CMObjectSecurityScope -InputObject $CMPackage -Name 'Stores-Production'
			#Remove-CMObjectSecurityScope -InputObject $CMPackage -Name 'Stores-TCoE Lab'
		}
	}
	End {
	}
}
################################################################################
################################################################################
#endregion ######################### Functions #################################

#region    ######################### Initialization ############################

#Remove-Variable -Name ScriptInfo -Scope global -ErrorAction SilentlyContinue
Get-ScriptInfo -FullPath $ScriptFullPath
Remove-Variable FunctionLibrary -ErrorAction SilentlyContinue
Remove-Variable ScriptFullPath -ErrorAction SilentlyContinue

#endregion ######################### Initialization ############################