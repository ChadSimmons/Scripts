#Deprecated !!!! New-CustomScript.ps1 and CustomScriptFunctions.ps1 should be used whenever possible !!!!!!!!!!!!!!!!!!!

################################################################################
#.SYNOPSIS
#   ScriptFileName.ps1
#   A brief description of the function or script. This keyword can be used only once in each topic.
#.DESCRIPTION
#   A detailed description of the function or script. This keyword can be used only once in each topic.
#	About Comment Based Help https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_comment_based_help?view=powershell-5.1
#.PARAMETER <name>
#   Specifies <xyz>
#.EXAMPLE
#   ScriptFileName.ps1 -Parameter1
#   A sample command that uses the function or script, optionally followed by sample output and a description. Repeat this keyword for each example.
#.LINK
#   Link Title: http://contoso.com/ScriptFileName.txt
#   The name of a related topic. The value appears on the line below the .LINE keyword and must be preceded by a comment symbol (#) or included in the comment block.
#   Repeat the .LINK keyword for each related topic.
#   This content appears in the Related Links section of the help topic.
#   The Link keyword content can also include a Uniform Resource Identifier (URI) to an online version of the same help topic. The online version  opens when you use the Online parameter of Get-Help. The URI must begin with "http" or "https".
#.NOTES
#   This script is maintained at https://github.com/ChadSimmons/Scripts
#   Additional information about the function or script.
#   ========== Keywords ==========
#   Keywords: ???
#   ========== Change Log History ==========
#   - yyyy/mm/dd by Chad Simmons - Modified $ChangeDescription$
#   - yyyy/mm/dd by Chad.Simmons@CatapultSystems.com - Created
#   - yyyy/mm/dd by Chad@ChadsTech.net - Created
#   === To Do / Proposed Changes ===
#   - TODO: None
#   ========== Additional References and Reading ==========
#   - <link title>: https://domain.url
################################################################################
#region    ######################### Parameters and variable initialization ####
	[CmdletBinding()] #(SupportsShouldProcess=$false, ConfirmImpact="Low")
	Param (
		[Parameter(Mandatory=$true)]$Parameter1
	)
	#region    ######################### Debug code
		<#
		$Parameter1="this is a string"
		#>
	#endregion ######################### Debug code
#endregion ######################### Parameters and variable initialization ####

End { #Input Processing Order tip to move functions to the bottom of a script https://mjolinor.wordpress.com/2012/03/11/begin-process-end-not-just-for-functions/
	#region    ######################### Initialization ############################
	#$Global:Console = $true
	#$Global:EventLog = $true
	#$VerbosePreference = 'Continue'
	## ScriptNameAndPath (based on PowerShell Application Deployment Toolkit version 3.6.9)
	#Get-ScriptInfo -FullPath $(If (Test-Path -LiteralPath 'variable:HostInvocation') { $HostInvocation.MyCommand.Definition } Else { $MyInvocation.MyCommand.Definition })
	Start-Script -LogFile "$env:WinDir\Logs\$($ScriptInfo.BaseName).log"
	$Progress = @{Activity = "$($ScriptInfo.Name)..."; Status = "Initializing..."} ; Write-Progress @Progress

	#endregion ######################### Initialization ############################
	#region    ######################### Main Script ###############################


	write-Output 'Hello'
	write-Verbose 'Verbose Hello'
	write-Debug 'Debug Hello'

	#Determine if a parameter was passed to the script/function
	If ($PSBoundParameters.ContainsKey('ParamString')) {
		Write-Output 'The script parameter [ParamString] was passed as [' + $ParamString + ']'
	} else {
		Write-Output 'The script parameter [ParamString] was not passed'
	}

	$List = @('1', '2', '3')
	$i = 0
	ForEach ($Item in $List) {
		$i++
		$Progress.Status = "Status [$i of $($List.Count)]"
		Write-Progress @Progress -CurrentOperation 'Current Operation' -PercentComplete $($i / $($List.count) * 100)
		Write-LogMessage -Message "Item $Item" -Type 'Info'
		Start-Sleep -Milliseconds 900
	}


	#endregion ######################### Main Script ###############################
	#region    ######################### Deallocation ##############################
	Write-Output "LogFile    is $($ScriptInfo.LogFile)"
	If ($OutputFile) { Write-Output "OutputFile is $OutputFile" }
	Stop-Script -ReturnCode 0
	#endregion ######################### Deallocation ##############################
}
Begin {
#region    ######################### Functions #################################
################################################################################
################################################################################
Function Get-ScriptInfo ($FullPath) {
	#.Synopsis
	#   Get the name and path of the script file
	#.Description
	#   Sets global variables for ScriptStartTime, ScriptNameAndPath, ScriptPath, ScriptName, ScriptBaseName, and ScriptLog
	#   This function works inline or in a dot-sourced script
	#   See snippet Get-ScriptInfo.ps1 for excruciating details and alternatives
	If (Test-Path variable:Global:ScriptInfo) { Write-Verbose 'ScriptInfo already set'
	} ElseIf ($ScriptInfo -is [object]) { Write-Verbose 'ScriptInfo already set'
	} Else {
		$Global:ScriptInfo = New-Object -TypeName PSObject
		Add-Member -InputObject $Global:ScriptInfo -MemberType NoteProperty -Name 'StartTime' -Value $(Get-Date) #-Description 'The date and time the script started'
		Add-Member -InputObject $Global:ScriptInfo -MemberType NoteProperty -Name 'EndTime' -Value $Null #-Description 'The date and time the script completed'

		If ([string]::IsNullorEmpty($FullPath) -or (-not(Test-Path -Path $FullPath))) {
			#The ScriptNameAndPath was not passed, thus detect it
			If ($psISE) {
				Add-Member -InputObject $Global:ScriptInfo -MemberType NoteProperty -Name 'FullPath' -Value $psISE.CurrentFile.FullPath #-Description 'The full path/folder/directory, name, and extension script file'
				Write-Verbose "Invoked ScriptPath from dot-sourced Script Function: $ScriptInfo.FullPath"
			} ElseIf ($((Get-Variable MyInvocation -Scope 1).Value.InvocationName) -eq '.') {
				#this script has been dot-sourced... https://stackoverflow.com/questions/4875912/determine-if-powershell-script-has-been-dot-sourced
				Add-Member -InputObject $Global:ScriptInfo -MemberType NoteProperty -Name 'FullPath' -Value (Get-Variable MyInvocation -Scope 1).Value.ScriptName #-Description 'The full path/folder/directory, name, and extension script file'
				Write-Verbose "Invoked ScriptPath from dot-sourced Script Function: $ScriptInfo.FullPath"
			} Else {
				Add-Member -InputObject $Global:ScriptInfo -MemberType NoteProperty -Name 'FullPath' -Value $script:MyInvocation.MyCommand.Path #-Description 'The full path/folder/directory, name, and extension script file'
				Write-Verbose "Invoked ScriptPath from Invoked Script Function: $ScriptInfo.FullPath"
			}
		} else {
			Write-Verbose -Message "Called Function Get-ScriptInfo -FullPath $FullPath"
			Add-Member -InputObject $Global:ScriptInfo -MemberType NoteProperty -Name 'FullPath' -Value $FullPath #-Description 'The full path/folder/directory, name, and extension script file'
		}
		Write-Verbose "ScriptInfo.FullPath    is $($ScriptInfo.FullPath)"
		Add-Member -InputObject $Global:ScriptInfo -MemberType NoteProperty -Name 'Path' -Value $(Split-Path -Path $ScriptInfo.FullPath -Parent) #-Description 'The path/folder/directory containing the script file'
		Add-Member -InputObject $Global:ScriptInfo -MemberType NoteProperty -Name 'Name' -Value $(Split-Path -Path $ScriptInfo.FullPath -Leaf) #-Description 'The name and extension of the script file'
		Add-Member -InputObject $Global:ScriptInfo -MemberType NoteProperty -Name 'BaseName' -Value $([System.IO.Path]::GetFileNameWithoutExtension($ScriptInfo.Name)) #-Description 'The name without the extension of the script file'
		Add-Member -InputObject $Global:ScriptInfo -MemberType NoteProperty -Name 'LogPath' -Value $($ScriptInfo.Path) #-Description 'The full path/folder/directory, name, and extension script file with log extension'
		Add-Member -InputObject $Global:ScriptInfo -MemberType NoteProperty -Name 'LogFile' -Value $($ScriptInfo.Path + '\' + $ScriptInfo.BaseName + '.log') #-Description 'The full path/folder/directory, name, and extension script file with log extension'
		Add-Member -InputObject $Global:ScriptInfo -MemberType NoteProperty -Name 'LogFullPath' -Value $ScriptInfo.LogFile #-Description 'The full path/folder/directory, name, and extension script file with log extension'
	}
	Write-Verbose "ScriptInfo.FullPath    is $($ScriptInfo.FullPath)"
	Write-Verbose "ScriptInfo.Path		is $($ScriptInfo.Path)"
	Write-Verbose "ScriptInfo.Name		is $($ScriptInfo.Name)"
	Write-Verbose "ScriptInfo.BaseName    is $($ScriptInfo.BaseName)"
	Write-Verbose "ScriptInfo.LogFile     is $($ScriptInfo.LogFile)"
	Write-Verbose "ScriptInfo.StartTime   is $($ScriptInfo.StartTime)"
}
Function Get-CurrentLineNumber {
	If ($psISE) { $script:CurrentLine = $psISE.CurrentFile.Editor.CaretLine
	} else { $script:CurrentLine = $MyInvocation.ScriptLineNumber }
	return $script:CurrentLine
}
Function Get-CurrentFunctionName {
	return (Get-Variable MyInvocation -Scope 1).Value.MyCommand.Name
}
Function Write-LogMessage {
	#.Synopsis Write a log entry in CMtrace format
	#.Notes    2017/05/16 by Chad@chadstech.net - based on Ryan Ephgrave's CMTrace Log Function @ http://www.ephingadmin.com/powershell-cmtrace-log-function
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
	#.Parameter Console
	#	Display the Message in the console
	Param (
		[Parameter(Mandatory=$true)][string]$Message,
		[Parameter()][ValidateSet('Error','Warn','Warning','Info','Information','1','2','3')][string]$Type,
		[Parameter()][string]$Component = $($ScriptInfo.BaseName),
		[Parameter()][string]$LogFile = $($ScriptInfo.LogFile),
		[Parameter()][switch]$Console
	)
	Switch ($Type) {
		{ @('3', 'Error') -contains $_ } { $intType = 3 } #3 = Error (red)
		{ @('2', 'Warn', 'Warning') -contains $_ } { $intType = 2 } #2 = Warning (yellow)
		Default { $intType = 1 } #1 = Normal
	}
	If ($LogFile.Length -lt 6) {$LogFile = "$env:WinDir\Logs\Script.log"} #Must not be null
	If ($Component -eq $null) {$Component = ' '} #Must not be null
	If ($Message -eq $null) {$Message = '<blank>'} #Must not be null or blank
	If ($Console) { Write-Output $Message } #write to console if enabled
	If (-not(Test-Path -Path 'variable:global:TimezoneBias')) {
		[string]$global:TimezoneBias = [System.TimeZoneInfo]::Local.GetUtcOffset((Get-Date)).TotalMinutes
		If ( $timezoneBias -match "^-" ) {
			# flip the offset value from negative to positive
			$timezoneBias = $timezoneBias.Replace('-', '+')
		} else {
			$timezoneBias = '-' + $timezoneBias
		}
	}
	try {
		#write log file message
		"<![LOG[$Message]LOG]!><time=`"$(Get-Date -Format HH:mm:ss.fff)$($global:TimeZoneBias)`" date=`"$(Get-Date -Format "MM-dd-yyyy")`" component=`"$Component`" context=`"`" type=`"$intType`" thread=`"$PID`" file=`"$Component`">" | Out-File -Append -Encoding UTF8 -FilePath $LogFile
	} catch { Write-Error "Failed to write to the log file '$LogFile'" }
}
Function Start-ArchiveLogFile {
	#.Synopsis
	#	Archive the log file if the size is beyond a threshold
	#.Parameter LogFile
	#	The file the message will be logged to
	#.Parameter LogFileMaxSizeMB
	#	Maximum file size limit for log file in megabytes (MB). Default is 2 MB.
	#.Example   Start-ArchiveLogFile
	#.Example   Start-ArchiveLogFile -LogFile "$env:WinDir\Logs\Scripts\CustomScripts.log" -LogFileMaxSizeMB = 0.2
	Param (
		[Parameter()][ValidateNotNullorEmpty()][string]$LogFile = $($ScriptInfo.LogFile),
		[Parameter()][ValidateRange(0.1, 100)][decimal]$LogFileMaxSizeMB = 2
	)
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
				Write-LogMessage -Message "Maximum log file size [$LogFileMaxSizeMB MB] reached. Rename log file to [$LogFileArchive]." -Component 'SYSTEM' -Type 'Info'
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
	Get-ScriptInfo -FullPath $(If (Test-Path -LiteralPath 'variable:HostInvocation') { $HostInvocation.MyCommand.Definition } Else { $MyInvocation.MyCommand.Definition })
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
	If (!(Test-Path $ScriptInfo.LogPath)) { New-Item -Path $ScriptInfo.LogPath -ItemType Directory -Force}
	#write initial message
	Start-ArchiveLogFile -LogFile $($ScriptInfo.LogFile)
	Write-LogMessage -Message "==================== SCRIPT START ===================="
	Write-Verbose "Logging to $($ScriptInfo.LogFile)"
}
Function Stop-Script ($ReturnCode) {
	#Required: Get-ScriptInfo(), Write-LogMessage()
	Write-LogMessage -Message "Exiting with return code $ReturnCode"
	$ScriptInfo.EndTime = $(Get-Date) #-Description 'The date and time the script completed'
	$ScriptTimeSpan = New-TimeSpan -Start $ScriptInfo.StartTime -End $ScriptInfo.EndTime #New-TimeSpan -seconds $(($(Get-Date)-$StartTime).TotalSeconds)
	Write-LogMessage -Message "Script Completed in $([math]::Round($ScriptTimeSpan.TotalSeconds)) seconds, started at $(Get-Date $ScriptInfo.StartTime -Format 'yyyy/MM/dd hh:mm:ss'), and ended at $(Get-Date $ScriptInfo.EndTime -Format 'yyyy/MM/dd hh:mm:ss')" -Console
	Write-LogMessage -Message "==================== SCRIPT COMPLETE ===================="
	Write-Verbose -Message $($ScriptInfo | Format-List | Out-String)
	Exit $ReturnCode
}
################################################################################
################################################################################
#endregion ######################### Functions #################################
}