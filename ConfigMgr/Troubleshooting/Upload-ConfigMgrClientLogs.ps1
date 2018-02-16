#.Synopsis
#   Upload-ConfigMgrClientLogs.ps1
#   Compress ConfigMgr setup logs, client logs, and custom logs and copy to the specified Server or the associated Management Point
#.Notes
#	This script is maintained at https://github.com/ChadSimmons/Scripts/ConfigMgr
#	Additional information about the function or script.
#   - This script should be compatible with PowerShell 2.0 to support Windows 7 default version as well as older operating systems
#   - This script can be deployed as a ConfigMgr Package, Application, Compliance Setting, or Script
#	========== Change Log History ==========
#	- 2017/10/30 by Chad.Simmons@CatapultSystems.com - Created
#	- 2017/10/30 by Chad@ChadsTech.net - Created
#	=== To Do / Proposed Changes ===
#	- TODO: None
#	========== Additional References and Reading ==========
#   - Based on https://blogs.technet.microsoft.com/setprice/2017/08/16/automating-collection-of-config-mgr-client-logs
#   - Based on http://ccmexec.com/2017/10/powershell-script-to-collect-sccm-log-files-from-clients-using-run-script/

#[cmdletBinding()]
#param ( [switch]$DeleteLocalArchive )
#Set Variables
$LogServer = '' #if blank, the client Management Point will be used
$SharePath = 'ConfigMgrClientLogs/ConfigMgrClient'
$DeleteLocalArchive = $false
$LogPaths = @() #create a hashtable of Log Names and Paths.  The ConfigMgr client logs and ccmsetup logs are added to the list later
$LogPaths += @{'LogName' = 'Panther'; 'LogPath' = "$env:WinDir\Panther"; 'LogFilter' = '*.*'; 'Recurse' = $true}
$LogPaths += @{'LogName' = 'WinDirLogs'; 'LogPath' = "$env:WinDir\Logs"; 'LogFilter' = '*.*'; 'Recurse' = $false}
$LogPaths += @{'LogName' = 'WinDirLogsSoftware'; 'LogPath' = "$env:WinDir\Logs\Software"; 'LogFilter' = '*.*'; 'Recurse' = $true}

#region    ######################### Functions #################################
################################################################################
Function Get-ScriptPath {
	#.Synopsis
	#   Get the folder of the script file
	#.Notes
	#   See snippet Get-ScriptPath.ps1 for excrutiating details and alternatives
	If ($psISE -and [string]::IsNullOrEmpty($script:ScriptPath)) {
		$script:ScriptPath = Split-Path $psISE.CurrentFile.FullPath -Parent #this works in psISE and psISE functions
	} else {
		try {
			$script:ScriptPath = Split-Path -Path $((Get-Variable MyInvocation -Scope 1 -ErrorAction SilentlyContinue).Value).MyCommand.Path -Parent
		} catch {
			$script:ScriptPath = "$env:WinDir\Logs"
		 }
	}
	Write-Verbose "Function Get-ScriptPath: ScriptPath is $($script:ScriptPath)"
	Return $script:ScriptPath
}
Function Get-ScriptName {
	#.Synopsis
	#   Get the name of the script file
	#.Notes
	#   See snippet Get-ScriptPath.ps1 for excrutiating details and alternatives
	If ($psISE) {
		$script:ScriptName = Split-Path $psISE.CurrentFile.FullPath -Leaf #this works in psISE and psISE functions
	} else {
		$script:ScriptName = ((Get-Variable MyInvocation -Scope 1 -ErrorAction SilentlyContinue).Value).MyCommand.Name
	}
	$script:ScriptBaseName = [System.IO.Path]::GetFileNameWithoutExtension($script:ScriptName)
	Write-Verbose "Function Get-ScriptName: ScriptName is $($script:ScriptName)"
	Write-Verbose "Function Get-ScriptName: ScriptBaseName is $($script:ScriptBaseName)"
	return $script:ScriptName
}
Function Write-LogMessage {
	#.Synopsis
	#   Write a log entry in CMtrace format
	Param (
		[Parameter(Mandatory = $true)]$Message,
		[ValidateSet('Error', 'Warn', 'Warning', 'Info', 'Information', '1', '2', '3')][string]$Type,
		$Component = $script:ScriptName,
		$LogFile = $script:LogFile,
		[switch]$Console
	)
	Switch ($Type) {
		{ @('3', 'Error') -contains $_ } { $intType = 3 } #3 = Error (red)
		{ @('2', 'Warn', 'Warning') -contains $_ } { $intType = 2 } #2 = Warning (yellow)
		Default { $intType = 1 } #1 = Normal
	}
	If ($Component -eq $null) {$Component = ' '} #Must not be null
	try {
		"<![LOG[$Message]LOG]!><time=`"$(Get-Date -Format "HH:mm:ss.ffffff")`" date=`"$(Get-Date -Format "MM-dd-yyyy")`" component=`"$Component`" context=`"`" type=`"$Type`" thread=`"`" file=`"`">" | Out-File -Append -Encoding UTF8 -FilePath $LogFile
	} catch {
		Write-Error "Failed to write to the log file '$LogFile'"
	}
	If ($Console) { Write-Output $Message } #write to console if enabled
}; Set-Alias -Name 'Write-CMEvent' -Value 'Write-LogMessage' -Description 'Log a message in CMTrace format'
Function Start-Script ($LogFile) {
	$script:ScriptStartTime = Get-Date
	$script:ScriptPath = Get-ScriptPath
	$script:ScriptName = Get-ScriptName

	#If the LogFile is undefined set to \Windows\Logs\<ScriptName>log #<ScriptPath>\<ScriptName>.log
	If ([string]::IsNullOrEmpty($LogFile)) {
		$script:LogFile = "$env:WinDir\Logs\$([System.IO.Path]::GetFileNameWithoutExtension($script:ScriptName)).log"
		#$script:LogFile = "$script:ScriptPath\$([System.IO.Path]::GetFileNameWithoutExtension($script:ScriptName)).log"
	} else { $script:LogFile = $LogFile }

	#If the LogFile folder does not exist, create the folder
	Set-Variable -Name LogPath -Value $(Split-Path -Path $script:LogFile -Parent) -Description 'The folder/directory containing the log file' -Scope Script
	If (-not(Test-Path $LogPath)) { New-Item -Path $LogPath -ItemType Directory -Force}

	Write-LogMessage -Message "==================== SCRIPT START ====================" -Component $script:ScriptName
	Write-Output "Logging to $script:LogFile"
}
Function Stop-Script ($ReturnCode) {
	Write-LogMessage -Message "Exiting with return code $ReturnCode"
	$ScriptEndTime = Get-Date
	$ScriptTimeSpan = New-TimeSpan -Start $script:ScriptStartTime -end $ScriptEndTime #New-TimeSpan -seconds $(($(Get-Date)-$StartTime).TotalSeconds)
	Write-LogMessage -Message "Script Completed in $([math]::Round($ScriptTimeSpan.TotalSeconds)) seconds, started at $(Get-Date $script:ScriptStartTime -Format 'yyyy/MM/dd hh:mm:ss'), and ended at $(Get-Date $ScriptEndTime -Format 'yyyy/MM/dd hh:mm:ss')"
	Write-LogMessage -Message "==================== SCRIPT COMPLETE ====================" -Component $script:ScriptName
	Exit $ReturnCode
}
Function Remove-Archive {
	#Delete the local archive file
	If ($DeleteLocalArchive -eq $true) {
		Remove-Item -Path "$CCMclientLogsPath\$localArchiveFileName" -ErrorAction SilentlyContinue
		Write-LogMessage -Message "Deleted '$CCMclientLogsPath\$localArchiveFileName'"
	}
}
################################################################################
#endregion ######################### Functions #################################

#region    ######################### Main Script ###############################
Start-Script -LogFile "$env:WinDir\Logs\Upload-ConfigMgrClientLogs.log"
$TempPath = "$env:Temp\$([System.Guid]::NewGuid().ToString())"
$remoteArchiveFileName = "$($env:ComputerName).$(Get-Date -format 'yyyyMMdd_HHmm').zip"
$localArchiveFileName = "ConfigMgrClientLogArchive.$(Get-Date -format 'yyyyMMdd_HHmm').zip"
$ReturnCode = 0

#Add CCMSetup log path to list of log paths
$LogPaths += @{'LogName' = 'CCMSetup'; 'LogPath' = "$env:WinDir\ccmsetup\logs"; 'LogFilter' = '*.log'; 'Recurse' = $false}

#Add ConfigMgr Client log path to list of log paths
try {
	$CCMclientLogsPath = Get-ItemProperty "HKLM:\Software\Microsoft\CCM\Logging\@global" -ErrorAction Stop | Select-Object -ExpandProperty LogDirectory
} catch {
	try {
		$CCMclientLogsPath = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\SMS\Client\Configuration\Client Properties" -ErrorAction Stop | Select-Object -ExpandProperty 'Local SMS Path'
	} catch {
		try {
			$CCMclientLogsPath = Split-Path -Path $(Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\services\CcmExec" -ErrorAction Stop | Select-Object -ExpandProperty ImagePath) -Parent
		} catch {
			$CCMclientLogsPath = "$env:WinDir\CCM"
		}
   }
	If ($CCMclientLogsPath -like "`"*") {
		#handle case where a double-quote starts the variable and optionally ends it
      $CCMclientLogsPath = $CCMclientLogsPath.Split('"')[1]
    }
   $CCMclientLogsPath = "$CCMclientLogsPath\Logs"
}
Write-LogMessage -Message "CCMclientLogsPath is $CCMclientLogsPath"
$LogPaths += @{'LogName' = 'CCMClient'; 'LogPath' = "$CCMclientLogsPath"; 'LogFilter' = '*.lo*'; 'Recurse' = $false}

#Verify the ConfigMgr Client logs folder is accessible
If (-not(Test-Path -Path "$CCMclientLogsPath")) {
	Write-LogMessage -Message "Failed to access path '$CCMclientLogsPath'." -Type Error -Console
	Stop-Script -ReturnCode -2
}
#Create the Temporary folder
If (-not(Test-Path -Path "$TempPath")) {
	try {
		New-Item -itemType Directory -Path "$TempPath" -ErrorAction Stop | Out-Null
		Write-LogMessage -Message "Created path '$TempPath'."
	} catch {
		Write-LogMessage -Message "Failed to create path '$TempPath'." -Type Error -Console
		Stop-Script -ReturnCode -2
	}
}
#Copy files to the Temporary folder
$LogPaths | ForEach-Object {
	$LogPath = $_.LogPath
	If (Test-Path -Path $LogPath) {
		$LogName = $_.LogName
		$LogFilter = $_.LogFilter
		try {
			If (-not(Test-Path -Path "$TempPath\$LogName")) {
				New-Item -itemType Directory -Path "$TempPath" -name "$LogName" -ErrorAction Stop | Out-Null
				Write-LogMessage -Message "Created path '$TempPath\$LogName'."
			}
			If ($_.Recurse) {
				Copy-Item -Path "$LogPath\$LogFilter" -Destination "$TempPath\$LogName" -Force -ErrorAction Stop -Recurse
			} else {
				Copy-Item -Path "$LogPath\$LogFilter" -Destination "$TempPath\$LogName" -Force -ErrorAction Stop
			}
			Write-LogMessage -Message "Copied $LogFilter from '$LogPath' to '$TempPath\$LogName'."
		} catch {
			Write-LogMessage -Message "Failed to copy $LogFilter from '$LogPath' to '$TempPath\$LogName'." -Type Warn -Console
		}
	} else {
		Write-LogMessage -Message "The path '$LogPath' does not exist or is inaccessible." -Type Warn -Console
	}
}

#Compress the tempoary folder
try {
	Add-Type -Assembly System.IO.Compression.FileSystem
	[System.IO.Compression.ZipFile]::CreateFromDirectory("$TempPath", "$CCMclientLogsPath\$localArchiveFileName", $([System.IO.Compression.CompressionLevel]::Optimal), $false)
	Write-LogMessage -Message "Compressed folder '$TempPath' to '$CCMclientLogsPath\$localArchiveFileName'"
	#Remove the temporary folders and files
	Remove-Item -Path "$TempPath" -Recurse -Force -ErrorAction SilentlyContinue
	Write-LogMessage -Message "Removed temporary folder '$TempPath'"
} catch {
	Write-LogMessage -Message "Failed to compress folder '$TempPath' to '$CCMclientLogsPath\$localArchiveFileName'" -Type Error -Console
	Remove-Item -Path "$TempPath" -Recurse -Force -ErrorAction SilentlyContinue
	Write-LogMessage -Message "Removed temporary folder '$TempPath'"
	Remove-Archive
	Stop-Script -ReturnCode -3
}

#attempt to set the server share to the client's Management Point
If ([string]::IsNullOrEmpty($LogServer)) {
	try {
		#$ConfigMgrMP = (Get-CIMinstance -Namespace 'root\ccm\LocationServices' -ClassName sms_mpinformation).MP[0]
		$LogServer = (Get-WmiObject -Namespace 'root\CCM\LocationServices' -Class 'SMS_MPInformation' -Property 'MP').MP[0]
	} catch {
		Write-LogMessage -Message "Failed to retrieve ConfigMgr Management Point '$LogServer'." -Type Error -Console
		Remove-Archive
		Stop-Script -ReturnCode -8
	}
}
$LogServerLogsURIPath = "http://$LogServer/$SharePath"
$LogServerLogsUNCPath = "\\$LogServer\$SharePath"

#verify the server share is online
If (-not(Test-Connection -ComputerName $LogServer -Quiet -Count 1)) {
	#TODO: test HTTP connectivity on ConfigMgr's port.  Ensure it works with PoSH 2.0
	Write-LogMessage -Message "Failed to communicate with log server '$LogServer'." -Type Error -Console
	Remove-Archive
	Stop-Script -ReturnCode -9
}

#send archive to server share
try {
	#Copy the archive file to the file share using SMB
	Copy-Item -Path "$CCMclientLogsPath\$localArchiveFileName" -Destination "$LogServerLogsUNCPath\$remoteArchiveFileName"
	Write-LogMessage -Message "Copied '$CCMclientLogsPath\$localArchiveFileName' to '$LogServerLogsUNCPath\$remoteArchiveFileName'" -Console
} catch {
	Write-LogMessage -Message "Failed to copy '$CCMclientLogsPath\$localArchiveFileName' to '$LogServerLogsUNCPath\$remoteArchiveFileName'"
	#Copy the archive file to the file share using BITS
	try {
		Import-Module BitsTransfer -Force
		Start-BitsTransfer -Source "$CCMclientLogsPath\$localArchiveFileName" -Destination "$LogServerLogsURIPath/$remoteArchiveFileName" -TransferType Upload
		Write-LogMessage -Message "Uploaded '$CCMclientLogsPath\$localArchiveFileName' to '$LogServerLogsURIPath/$remoteArchiveFileName'" -Console
	} catch {
		Write-LogMessage -Message "Failed to upload '$CCMclientLogsPath\$localArchiveFileName' to '$LogServerLogsURIPath/$remoteArchiveFileName'" -Console
		Remove-Archive
		Stop-Script -ReturnCode -1
	}
}

Remove-Archive
Stop-Script -ReturnCode 0