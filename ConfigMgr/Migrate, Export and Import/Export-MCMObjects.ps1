#requires -Version 3.0
################################################################################
#.SYNOPSIS
#   Export-MECMObjects.ps1
#   Export ConfigMgr Console objects to native files formats
#.PARAMETER ExportPathRoot
#   Specifies the root path to export files to, for example \\Sever\Share\Folder\SCCMObjects
#   Subfolders will be created for each object type
#.PARAMETER SiteServer
#   Specifies the ConfigMgr Site Server to export object from
#.PARAMETER SiteCode
#   Specifies the ConfigMgr Site Code to export object from
#.PARAMETER ObjectTypes
#   Specifies the types of objects which should be exported.  Blank and All export every supported type
#.PARAMETER WithDependencies
#   Specifies that object types which have dependencies should export the dependencies.
#.PARAMETER WithContent
#   Specifies that object types which have content should export the content.  Be careful with this especially with Task Sequences
#.EXAMPLE
#   Export-CMCMQueries.ps1 -SiteCode ABC -SiteServer
#.EXAMPLE
#   Export-MECMQueries.ps1 -SiteCode ABC -ExportPathRoot "\\Sever\Share\Folder Name\CMObjects"
#.NOTES
#   This script is maintained at https://github.com/ChadSimmons/Scripts
#   Additional information about the function or script.
#   ========== Keywords ==========
#   Keywords: ConfigMgr SCCM Object Export Import Migrate Migration
#   ========== Change Log History ==========
#   - 2020/10/26 by Chad.Simmons@CatapultSystems.com - updated collection export and added ObjectTypes parameter
#   - 2020/09/30 by Chad.Simmons@CatapultSystems.com - minor updates
#   - 2018/12/21 by Chad.Simmons@CatapultSystems.com - Created
#   - 2018/12/21 by Chad@ChadsTech.net - Created
#   === To Do / Proposed Changes ===
#   #TODO: Use CustomScrptFunctions.ps1 instead of embedding common functions
#   #TODO: Convert to a Module and support exporting of individual objects by ID or Name
#   #TODO: Support WhatIf
#   #TODO: Support Overwrite or Not
#   #TODO: Support Archiving/Compressing exported Content and Zip files since they are not compressed
#   #TODO: Add Write-Progress for all Object Types and Objects
#   #TODO: Add all other valid object types (only what can be imported via console or PowerShell?)
################################################################################
#region    ######################### Parameters and variable initialization ####
[CmdletBinding()] #(SupportsShouldProcess=$false, ConfirmImpact="Low")
Param (
	[Parameter()][string]$ExportPathRoot = $(Join-Path -Path $env:UserProfile -ChildPath 'Downloads\CMObjects'),
	[Parameter(Mandatory = $true, HelpMessage = 'Computer Fully Qualified Domain Name')][ValidateScript( { Resolve-DnsName -Name $_ })][string]$SiteServer = 'ConfigMgr.contoso.com',
	[Parameter(Mandatory = $true, HelpMessage = 'ConfigMgr Site Code')][ValidateLength(3, 3)][string]$SiteCode = 'LAB',
	[Parameter(HelpMessage = 'type of objects to export')][string[]]$ObjectTypes,
	[Parameter(HelpMessage = 'Export Dependency objects')][bool]$WithDependencies = $true,
	[Parameter(HelpMessage = 'Export Content with objects')][bool]$WithContent = $false
)
#region    ######################### Debug code

$ExportPathRoot = 'C:\DataLocal\ExportCMObjects'
$SiteCode = 'CM1'
$SiteServer = 'SCCM12.ati.corp.com'
$ObjectTypes = 'Collections'

#endregion ######################### Debug code
#endregion ######################### Parameters and variable initialization ####

#region    ######################### Functions #################################
################################################################################
################################################################################
Function Get-ScriptInfo ($FullPath) {
	#.Synopsis
	#   Get the name and path of the script file
	#.Description
	#   Sets script variables for ScriptFullPath, ScriptPath, ScriptName, ScriptBaseName, LogFile
	#.Notes    2018/10/17 by Chad.Simmons@CatapultSystems.com - updated
	#          2017/01/01 by Chad@chadstech.net - created
	#.Example  Get-ScriptInfo -FullPath $(If (Test-Path -LiteralPath 'variable:HostInvocation') { $HostInvocation.MyCommand.Definition } Else { $MyInvocation.MyCommand.Definition })
	Set-Variable -Scope Script -Name ScriptStartTime -Value ($(Get-Date) -as [datetime]) -Description 'The date and time the script started' -WhatIf:$false
	Set-Variable -Scope Script -Name ScriptFullPath -Value ($null -as [string]) -Description 'The full path/folder/directory, name, and extension script file' -WhatIf:$false
	If (Test-Path -Path $FullPath) {
		$script:ScriptFullPath = $FullPath
	} ElseIf ($psISE) {
		$script:ScriptFullPath = $psISE.CurrentFile.FullPath
	} ElseIf ($((Get-Variable MyInvocation -Scope 1).Value.InvocationName) -eq '.') {
		$script:ScriptFullPath = (Get-Variable MyInvocation -Scope 1).Value.ScriptName
	} Else {
		$script:ScriptFullPath = $script:MyInvocation.MyCommand.Path
	}
	Set-Variable -Scope Script -Name ScriptPath -Value $(Split-Path -Path $script:ScriptFullPath -Parent) -Description 'The path/folder/directory containing the script file' -WhatIf:$false
	Set-Variable -Scope Script -Name ScriptName -Value $(Split-Path -Path $script:ScriptFullPath -Leaf) -Description 'The name and extension of the script file' -WhatIf:$false
	Set-Variable -Scope Script -Name ScriptBaseName -Value $([System.IO.Path]::GetFileNameWithoutExtension($script:ScriptName)) -Description 'The name without the extension of the script file' -WhatIf:$false
	Set-Variable -Scope Script -Name ScriptLogFullPath -Value $(Join-Path -Path $script:ScriptPath -ChildPath $([io.path]::ChangeExtension($script:ScriptName, 'log'))) -Description 'The full path/folder/directory, name, and extension script file with log extension' -WhatIf:$false
	Set-Variable -Scope Script -Name LogFile -Value $script:ScriptLogFullPath -Description 'The full path/folder/directory, name, and extension script file with log extension' -WhatIf:$false
}
Function Write-LogMessage {
	#.Synopsis Write a log entry in CMtrace format
	#.Notes    2018/10/17 by Chad.Simmons@CatapultSystems.com - updated
	#          2014/08/16 by Chad@chadstech.net - created based on Ryan Ephgrave's CMTrace Log Function @ http://www.ephingadmin.com/powershell-cmtrace-log-function
	#.Example  Write-LogMessage -Message "This is a normal message"
	#.Example  Write-LogMessage -Message 'This is a normal message' -LogFile $LogFile -Console -WinEvent -Verbose
	#.Example  Write-LogMessage -Message "This is a warning" -Type Warn -Component 'Test Component' -LogFile $LogFile -Verbose
	#.Example  Write-LogMessage -Message 'This is an Error!' -Type Error -Component "My Component" -LogFile $LogFile
	#.Parameter Message
	#	The message to write
	#.Parameter Type
	#	The type of message Information/Info/1, Warning/Warn/2, Error/3
	#.Parameter Component
	#	The source of the message being logged.  Typically the script name or function name.
	#.Parameter LogFile
	#	The file the message will be logged to.  Writes to C:\Windows\Logs\Script.log if LogFile not passed or defined
	#.Parameter Console
	#	Display the Message in the console
	#.Parameter WinEvent
	#	Write the Message to the Windows Application Event Log in addition to the LogFile
	Param (
		[Parameter(Mandatory = $true, HelpMessage = 'Content to be appended to the log file.')][string]$Message,
		[Parameter(HelpMessage = 'Severity for the log entry')][ValidateSet('Error', 'Warn', 'Warning', 'Info', 'Information', '1', '2', '3')][ValidateNotNullorEmpty()][string]$Type = '1',
		[Parameter(HelpMessage = 'Name of the log component/script/module that initiate the log entry.')][string]$Component = $Script:ScriptBaseName,
		[Parameter(HelpMessage = 'Name of the log file that will be written to.')][ValidateNotNullorEmpty()][string]$LogFile = $script:LogFile,
		[Parameter(HelpMessage = 'Switch to also display the Message to the screen')][switch]$Console,
		[Parameter(HelpMessage = 'Switch to also log the Message to the Windows Application Event Log')][switch]$WinEvent
	)
	If ([string]::IsNullOrEmpty($Message)) { $Message = '<blank>' } #Must not be null or blank
	Switch ($Type) {
		{ @('1', 'Info', 'Information', $null) -contains $_ } { $intType = 1; $EntryType = 'Information'; If ($Console) { Write-Output $Message } }
		{ @('2', 'Warn', 'Warning') -contains $_ } { $intType = 2; $EntryType = 'Warning'; If ($Console) { Write-Warning $Message } }
		{ @('3', 'Error') -contains $_ } { $intType = 3; $EntryType = 'Error'; If ($Console) { Write-Error $Message }	}
	}
	If (-not($Console)) { Write-Verbose -Message "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$EntryType]`t $Message" }
	If ($LogFile.Length -lt 6) { $LogFile = "$env:WinDir\Logs\Script.log" } #Must not be null
	If ([string]::IsNullOrEmpty($Component)) { $Component = ' ' } #Must not be null
	If (-not(Test-Path -Path 'variable:script:WindowsEventSource')) { $script:WindowsEventSource = 'WSH'; Set-WindowsEventSource -Name 'Custom Script' }
	If (-not(Test-Path -Path 'variable:global:TimezoneBias')) {
		[string]$global:TimezoneBias = [System.TimeZoneInfo]::Local.GetUtcOffset((Get-Date)).TotalMinutes -as [string]
		If ($TimezoneBias -match "^-") {
			$TimezoneBias = $TimezoneBias.Replace('-', '+')# flip the offset value from negative to positive
		} Else { $TimezoneBias = '-' + $TimezoneBias }
	}
	If (-not(Test-Path -Path 'variable:global:UserContext')) { [string]$global:UserContext = $([System.Security.Principal.WindowsIdentity]::GetCurrent().Name) }
	If ($WinEvent) { Write-EventLog -LogName Application -Source $script:WindowsEventSource -EntryType $EntryType -EventId 0 -Message $Message -WhatIf:$false }
	try {
		Out-File -Append -Encoding UTF8 -FilePath $LogFile -WhatIf:$false -InputObject "<![LOG[$Message]LOG]!><time=`"$(Get-Date -Format HH:mm:ss.fff)$($global:TimeZoneBias)`" date=`"$(Get-Date -Format "MM-dd-yyyy")`" component=`"$Component`" context=`"$UserContext`" type=`"$intType`" thread=`"$PID`" file=`"$Component`">"
	} catch {
		Write-Error -Message "Failed to write to the log file [$LogFile]`n[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$EntryType]`t $Message `nError message at line $($_.InvocationInfo.ScriptLineNumber): $($_.Exception.Message)" #TODO: -Category WriteError -Exception
		Write-EventLog -LogName Application -Source $script:WindowsEventSource -EntryType 'Error' -EventId 0 -Message "Failed to write to the log file [$LogFile]" -WhatIf:$false
		Write-EventLog -LogName Application -Source $script:WindowsEventSource -EntryType $EntryType -EventId 0 -Message $Message -WhatIf:$false
	}
}
Function Set-WindowsEventSource {
	#.Synopsis Create an Event Source for the Windows Application Event Log.  Requires administrative/elevated rights.
	#.Notes    2018/10/17 by Chad.Simmons@CatapultSystems.com - updated
	#          2018/10/10 by Chad@chadstech.net - created
	#.Example  Set-WindowsEventSource
	#.Example  Set-WindowsEventSource -Name 'Custom Script'
	#.Example  Set-WindowsEventSource -Name 'Custom Script' -FallbackName 'WSH' -Verbose
	#.Parameter Name
	#	The name of the event source to create/validate
	#.Parameter FallbackName
	#	The name of the event source to use if the Name event source cannot be created
	Param (
		[Parameter()][ValidateNotNullorEmpty()][Alias('Source', 'WindowsEventSource')][string]$Name = 'Custom Script',
		[Parameter()][ValidateNotNullorEmpty()][Alias('FallbackSource')][string]$FallbackName = 'WSH'
	)
	If (-not(Test-Path -Path 'variable:script:WindowsEventSource')) {
		#If the eventSource already exists, set the script variable
		If (Get-ChildItem -Path 'HKLM:\System\CurrentControlSet\services\eventlog\Application' -Name | Where-Object { $_.PSChildName -eq $Name }) {
			Set-Variable -Name WindowsEventSource -Scope Script -Value $Name -WhatIf:$false
		} else {
			Write-LogMessage -Message "Creating Windows Application Event Source [$Name]" -Type Info -Verbose
			Try {
				New-EventLog -LogName Application -Source $Name
				Set-Variable -Name WindowsEventSource -Scope Script -Value $Name -WhatIf:$false
				Write-LogMessage -Message "Created Windows Application Event Source [$Name]" -Type Info -Verbose
			} catch {
				Set-Variable -Name WindowsEventSource -Scope Script -Value $FallbackName -WhatIf:$false
				Write-LogMessage -Message "Could not create Windows Event Log Source.  Using fallback name of [$FallbackName] instead" -Type Warning -Verbose
			}
		}
	}
}
Function Remove-InvalidFileNameChars {
	#.Link https://stackoverflow.com/questions/23066783/how-to-strip-illegal-characters-before-trying-to-save-filenames
	param (
		[Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)][String]$Name,
		[Parameter(Mandatory = $false, Position = 1, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)][String]$ReplaceWith = '_'
	)
	$NewName = $Name.Split([IO.Path]::GetInvalidFileNameChars()) -join "$ReplaceWith"
	If ($Name -ne $NewName) { Write-Verbose -Message "Removed invalid file name characters from [$Name] yielding [$NewName]" }
	return $NewName
}
Function New-ExportPath {
	[CmdletBinding()] #(SupportsShouldProcess=$false, ConfirmImpact="Low")
	Param (
		[Parameter()][ValidateScript( { Test-Path -Path $_ -PathType 'Container' })][string]$RootPath = $script:ExportPathRoot,
		[Parameter(Mandatory = $true)][string]$Path
	)
	$ExportPath = Join-Path -Path $RootPath -ChildPath $Path
	#create export folder
	Push-Location $env:SystemDrive
	If (-not(Test-Path -Path $ExportPath)) {
		[void](New-Item -Path $ExportPath -ItemType Directory -Force)
	}
	Pop-Location
	Return $(Join-Path -Path $RootPath -ChildPath $Path)
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
	If ($Env:SMS_ADMIN_UI_PATH -ne $null) {
		#import the module if it exists
		If ((Get-Module ConfigurationManager) -eq $null) {
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
			Write-Verbose 'The ConfigMgr PowerShell Module is already loaded.'
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
		if ((Get-PSDrive -Name $SiteCode -PSProvider CMSite -ErrorAction SilentlyContinue) -eq $null) {
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
			Write-Error 'Error connecting to the ConfigMgr site'
			Throw $_
		}
	} else {
		Throw 'The ConfigMgr PowerShell Module does not exist!  Install the ConfigMgr Admin Console first.'
	}
}; Set-Alias -Name 'Connect-CMSite' -Value 'Connect-ConfigMgr' -Description 'Load the ConfigMgr PowerShell Module and connect to a ConfigMgr site'
Function Export-MECMQueries {
	[CmdletBinding()] #(SupportsShouldProcess=$false, ConfirmImpact="Low")
	Param (
		[Parameter(Mandatory = $true)][string]$Path,
		[Parameter(Mandatory = $true)][ValidateLength(3, 3)][string]$SiteCode,
		[Parameter(Mandatory = $false)][ValidateLength(9, 9)][string]$QueryID
	)
	Write-Verbose -Message 'Exporting ConfigMgr Queries...'
	Try {
		Push-Location -Path "$SiteCode`:"
		If ($QueryID) { $CMObjects = @(Get-CMQuery -QueryID $QueryID) }
		Else { $CMObjects = @(Get-CMQuery | Where-Object { $_.CMQuery -notlike 'SMS*' }) }

		Write-LogMessage -Message "Found $($CMObjects.count) ConfigMgr Query objects to export" -Type Info -Component 'Export-MECMQueries'
		$i = 0
		ForEach ($CMObject in $CMObjects) {
			$i++; Write-Output "Exporting $i of $($CMObjects.count) - $($CMObject.Name)"
			$ExportFile = Join-Path -Path $Path -ChildPath "$(Remove-InvalidFileNameChars -Name $(CMQuery - $CMObject.Name)).mof"
			If (Test-Path -Path $ExportFile -PathType Leaf) { Remove-Item -Path $ExportFile -Force }
			try {
				Export-CMQuery -InputObject $CMObject -ExportFilePath $ExportFile -Comment "$($CMObject.Comments)"
				Write-LogMessage -Message "Exported ConfigMgr Query object named [$($CMObject.Name)] to file [$ExportFile]" -Type Info -Component 'Export-CMQuery'
			} catch {
				Write-LogMessage -Message "Failed exporting ConfigMgr Query object named [$($CMObject.Name)] to file [$ExportFile]" -Type Error -Component 'Export-CMQuery'
			}
		}
		Remove-Variable -Name CMObjects, CMObject -ErrorAction SilentlyContinue | Out-Null
		Pop-Location
	} Catch {}
}
Function Export-MECMAntimalwarePolicies {
	[CmdletBinding()] #(SupportsShouldProcess=$false, ConfirmImpact="Low")
	Param (
		[Parameter(Mandatory = $true)][string]$Path,
		[Parameter(Mandatory = $true)][ValidateLength(3, 3)][string]$SiteCode
	)
	Write-Verbose -Message 'Exporting ConfigMgr Antimalware Policies...'
	Try {
		Push-Location -Path "$SiteCode`:"
		$CMObjects = Get-CMAntimalwarePolicy #{ $_.Name -ne 'Default Client Antimalware Policy' }
		Write-LogMessage -Message "Found $($CMObjects.count) ConfigMgr Antimalware Policy objects to export" -Type Info -Component 'Export-MECMAntimalwarePolicies'
		ForEach ($CMObject in $CMObjects) {
			$ExportFile = "$Path\$(Remove-InvalidFileNameChars -Name $($CMObject.Name)).xml"
			If (Test-Path -Path $ExportFile -PathType Leaf) { Remove-Item -Path $ExportFile -Force }
			try {
				Export-CMAntimalwarePolicy -InputObject $CMObject -Path $ExportFile
				Write-LogMessage -Message "Exported ConfigMgr Antimalware Policy object named [$($CMObject.Name)] to file [$ExportFile]" -Type Info -Component 'Export-CMAntimalwarePolicy'
			} catch {
				Write-LogMessage -Message "Failed exporting ConfigMgr Antimalware Policy object named [$($CMObject.Name)] to file [$ExportFile]" -Type Error -Component 'Export-CMAntimalwarePolicy'
			}
		}
		Remove-Variable -Name CMObjects, CMObject -ErrorAction SilentlyContinue | Out-Null
		Pop-Location
	} Catch {}
}
Function Export-MECMSoftwareMeteringRules {
	[CmdletBinding()] #(SupportsShouldProcess=$false, ConfirmImpact="Low")
	Param (
		[Parameter(Mandatory = $true)][string]$Path,
		[Parameter(Mandatory = $true)][ValidateLength(3, 3)][string]$SiteCode
	)
	Write-Verbose -Message 'Exporting ConfigMgr Software Metering Rules...'
	Try {
		Push-Location -Path "$SiteCode`:"
		$CMObjects = Get-CMSoftwareMeteringRule | Select-Object ProductName, OriginalFileName, FileName, FileVersion, LanguageID, Comment, Enabled
		$CMObjects | Export-Csv -Path "$Path\Software Metering Rules List.csv" -NoTypeInformation -Force
		Write-LogMessage -Message "Found $($CMObjects.count) ConfigMgr Software Metering Rules objects to export" -Type Info -Component 'Export-MECMSoftwareMeteringRules'
		Remove-Variable -Name CMObjects, CMObject, ExportFile -ErrorAction SilentlyContinue | Out-Null
		Pop-Location
	} Catch {}
}
Function Export-MECMConfigurationItems {
	[CmdletBinding()] #(SupportsShouldProcess=$false, ConfirmImpact="Low")
	Param (
		[Parameter(Mandatory = $true)][string]$Path,
		[Parameter(Mandatory = $true)][ValidateLength(3, 3)][string]$SiteCode
	)
	Write-Verbose -Message 'Exporting ConfigMgr Configuration Items...'
	Try {
		Push-Location -Path "$SiteCode`:"
		$CMObjects = Get-CMConfigurationItem
		Write-LogMessage -Message "Found $($CMObjects.count) ConfigMgr Configuration Items objects to export" -Type Info -Component 'Export-MECMConfigurationItem'
		ForEach ($CMObject in $CMObjects) {
			$ExportFile = Join-Path -Path $Path -ChildPath "$(Remove-InvalidFileNameChars -Name $($CMObject.LocalizedDisplayName)).cab"
			If (Test-Path -Path $ExportFile -PathType Leaf) { Remove-Item -Path $ExportFile -Force }
			try {
				Export-CMConfigurationItem -InputObject $CMObject -Path $ExportFile
				Write-LogMessage -Message "Exported ConfigMgr Configuration Item object named [$($CMObject.Name)] to file [$ExportFile]" -Type Info -Component 'Export-CMConfigurationItem'
			} catch {
				Write-LogMessage -Message "Failed exporting ConfigMgr Configuration Item object named [$($CMObject.Name)] to file [$ExportFile]" -Type Error -Component 'Export-CMConfigurationItem'
			}
			Remove-Variable -Name ExportFile -ErrorAction SilentlyContinue | Out-Null
		}
		Remove-Variable -Name CMObjects, CMObject -ErrorAction SilentlyContinue | Out-Null
		Pop-Location
	} Catch {}
}
Function Export-MECMBaselines {
	[CmdletBinding()] #(SupportsShouldProcess=$false, ConfirmImpact="Low")
	Param (
		[Parameter(Mandatory = $true)][string]$Path,
		[Parameter(Mandatory = $true)][ValidateLength(3, 3)][string]$SiteCode
	)
	Write-Verbose -Message 'Exporting ConfigMgr Baselines...'
	Try {
		Push-Location -Path "$SiteCode`:"
		$CMObjects = Get-CMBaseline
		Write-LogMessage -Message "Found $($CMObjects.count) ConfigMgr Baseline objects to export" -Type Info -Component 'Export-MECMBaseline'
		ForEach ($CMObject in $CMObjects) {
			$ExportFile = Join-Path -Path $Path -ChildPath "$(Remove-InvalidFileNameChars -Name $($CMObject.LocalizedDisplayName)).cab"
			If (Test-Path -Path $ExportFile -PathType Leaf) { Remove-Item -Path $ExportFile -Force }
			try {
				Export-CMBaseline -InputObject $CMObject -Path $ExportFile
				Write-LogMessage -Message "Exported ConfigMgr Baseline object named [$($CMObject.Name)] to file [$ExportFile]" -Type Info -Component 'Export-CMBaseline'
			} catch {
				Write-LogMessage -Message "Failed exporting ConfigMgr Baseline object named [$($CMObject.Name)] to file [$ExportFile]" -Type Error -Component 'Export-CMBaseline'
			}
		}
		Remove-Variable -Name CMObjects, CMObject, ExportFile -ErrorAction SilentlyContinue | Out-Null
		Pop-Location
	} Catch {}
}
Function Get-MEMCMDeviceCollectionMembers ($CollectionName, $CollectionID, $SiteCode = $SiteCode, $SiteServer = $SiteServer, $Source = 'SYSTEM' ) {
	If ($CollectionName) {
		$CollectionID = (Get-WmiObject -ComputerName $SiteServer -Namespace "root\SMS\site_$($SiteCode)" -Query "Select CollectionID from SMS_Collection Where Name = `"$CollectionName`"").CollectionID
	}
	If ($Source -eq 'SYSTEM') {
		$CMComputers = (Get-WmiObject -ComputerName $SiteServer -Namespace "root\SMS\site_$($SiteCode)" -Query "Select S.* from SMS_R_System S inner join SMS_FullCollectionMembership FCM on FCM.ResourceId = S.ResourceID Where FCM.CollectionID = `"$CollectionID`"")
	} ElseIf ($Source -eq 'DEVICE') {
		$CMComputers = (Get-WmiObject -ComputerName $SiteServer -Namespace "root\SMS\site_$($SiteCode)" -Query "Select S.* from SMS_CombinedDeviceResources S inner join SMS_FullCollectionMembership FCM on FCM.ResourceId = S.ResourceID Where FCM.CollectionID = `"$CollectionID`"")
	}
	Write-Verbose -Message "$($CMComputers) computers found in collection ID [$CollectionID] named [$CollectionName]"
	Return $CMComputers
}
Function Get-MEMCMUserCollectionMembers ($CollectionName, $CollectionID, $SiteCode = $SiteCode, $SiteServer = $SiteServer, $Source = 'USER' ) {
	If ($CollectionName) {
		$CollectionID = (Get-WmiObject -ComputerName $SiteServer -Namespace "root\SMS\site_$($SiteCode)" -Query "Select CollectionID from SMS_Collection Where Name = `"$CollectionName`"").CollectionID
	}
	$CMUsers = @()
	If ($Source -eq 'USER') {
		$CMUsers += (Get-WmiObject -ComputerName $SiteServer -Namespace "root\SMS\site_$($SiteCode)" -Query "Select S.* from SMS_R_User S inner join SMS_FullCollectionMembership FCM on FCM.ResourceId = S.ResourceID Where FCM.CollectionID = `"$CollectionID`"")
		$CMUsers += (Get-WmiObject -ComputerName $SiteServer -Namespace "root\SMS\site_$($SiteCode)" -Query "Select S.* from SMS_R_UserGroup S inner join SMS_FullCollectionMembership FCM on FCM.ResourceId = S.ResourceID Where FCM.CollectionID = `"$CollectionID`"")
		#telphoneNumber, physicalDeliveryOfficeName, employeeID
		#} ElseIf ($Source -eq 'DEVICE') {
		#	$CMUsers = (Get-WmiObject -ComputerName $SiteServer -Namespace "root\SMS\site_$($SiteCode)" -Query "Select S.* from SMS_CombinedDeviceResources S inner join SMS_FullCollectionMembership FCM on FCM.ResourceId = S.ResourceID Where FCM.CollectionID = `"$CollectionID`"")
	}
	Write-Verbose -Message "$($CMUsers) users and groups found in collection ID [$CollectionID] named [$CollectionName]"
	Return $CMUsers
}
Function Export-MECMCollections {
	[CmdletBinding()] #(SupportsShouldProcess=$false, ConfirmImpact="Low")
	Param (
		[Parameter(Mandatory = $true)][string]$Path,
		[Parameter(Mandatory = $true)][ValidateLength(3, 3)][string]$SiteCode,
		[Parameter(Mandatory = $false)][ValidateLength(8, 8)][string]$CollectionID
	)
	Write-Verbose -Message 'Exporting ConfigMgr Collections...'
	Try {
		Push-Location -Path "$SiteCode`:"
		If ($CollectionID) { $CMObjects = @(Get-CMCollection -CollectionID $CollectionID) }
		Else { $CMObjects = @(Get-CMCollection | Where-Object { $_.CollectionID -notlike 'SMS*' }) }
		Pop-Location
		Write-LogMessage -Message "Found $($CMObjects.count) ConfigMgr Collection objects to export" -Type Info -Component 'Export-MECMCollections'
		$i = 0
		ForEach ($CMObject in $CMObjects) {
			$i++; Write-Output "Exporting $i of $($CMObjects.count) - $($CMObject.Name)"
			try {
				$ExportPath = Join-Path -Path $Path -ChildPath $CMObject.CollectionID
				[void](New-Item -Path "filesystem::$ExportPath" -ItemType Container)

				Write-Output "Exporting Collection $($CMObject.CollectionID) - $($CMObject.Name)"
				Write-LogMessage -Message "Exporting ConfigMgr Collection object named [$($CMObject.Name)] to path [$ExportPath]" -Type Info -Component 'Export-MECMCollection'
				$CMObjectExportBasePath = Join-Path -Path $ExportPath -ChildPath $(Remove-InvalidFileNameChars -Name "Collection $($CMObject.CollectionID) - $($CMObject.Name)")
				$CMObject | Select-Object * | Out-File -FilePath "$CMObjectExportBasePath.Collection.txt"

				Push-Location -Path "$SiteCode`:"
				Export-CMCollection -CollectionId $CMObject.CollectionID -ExportFilePath "$CMObjectExportBasePath.mof" -force
				Get-CMCollectionSetting -CollectionId $CMObject.CollectionID | Select-Object * | Out-File -FilePath "$CMObjectExportBasePath.Settings.txt"
				Get-CMCollectionQueryMembershipRule -CollectionId $CMObject.CollectionID | Select-Object * | Out-File -FilePath "$CMObjectExportBasePath.QueryMembershipRule.txt"
				Get-CMCollectionExcludeMembershipRule -CollectionId $CMObject.CollectionID | Select-Object * | Out-File -FilePath "$CMObjectExportBasePath.ExcludeMembershipRule.txt"
				Get-CMCollectionIncludeMembershipRule -CollectionId $CMObject.CollectionID | Select-Object * | Out-File -FilePath "$CMObjectExportBasePath.IncludeMembershipRule.txt"
				Get-CMCollectionDirectMembershipRule -CollectionId $CMObject.CollectionID | Select-Object ResourceID, RuleName | Out-File -FilePath "$CMObjectExportBasePath.DirectMembershipRule.txt"
				#Get-CMCollectionMembershipRule -CollectionId $CMObject.CollectionID | Select-Object * | Out-File -FilePath "$CMObjectExportBasePath$..txt"
				If ($CMObject.CollectionType -eq 1) {
					#User Collection
					Get-CMCollectionMember -CollectionId $CMObject.CollectionID | Select-Object Name, ResourceId, SMSID, Domain, ResourceType | Export-Csv -Path "filesystem::$CMObjectExportBasePath.Members.csv" -NoTypeInformation
					Get-MEMCMUserCollectionMembers -CollectionId $CMObject.CollectionID -Source USER | Select-Object UniqueUserName, ResourceID, ResourceType, UserName, Name, displayname, WindowsNTDomain, distinguishedName, FullDomainName, FullUserName, UserPrincipalName, mail, mobile, telephoneNumber | Export-Csv -Path "filesystem::$CMObjectExportBasePath.Members.WMI_User.csv" -NoTypeInformation
					#TODO: handle user group collections details from WMI
					#ResourceType 4 is User, 3 is Group
				} ElseIf ($CMObject.CollectionType -eq 2) {
					#Device Collection
					Get-CMCollectionMember -CollectionId $CMObject.CollectionID | Select-Object Name, ResourceId, SMSID, SiteCode, ADSiteName, BoundaryGroups, ClientVerion, CNAccessMP, CNIsOnInternet, CNLastOnlineTime, CNLastOfflineTime, DeviceOS, DeviceOSBuild, Domain, IsClient, IsActive, LastMPServerName, MACAddress, LastActiveTime, LastLogonUser, CurrentLogonUser, PrimaryUser, UserName | Export-Csv -Path "filesystem::$CMObjectExportBasePath.Members.csv" -NoTypeInformation
					Get-MEMCMDeviceCollectionMembers -CollectionId $CMObject.CollectionID -Source SYSTEM | Select-Object Name, NetBiosName, ResourceId, SMSUniqueIdentifier, extensionAttribute11, Client, Active, ADSitename, ClientVersion, DistinguishedName, FullDomainName, OperatingSystemNameandVersion, Build, atiLastLoginIP, atiLastLoginUser, atiLastLoginUserTime, atiModel, atiSerial, atiSite | Export-Csv -Path "filesystem::$CMObjectExportBasePath.Members.WMI_System.csv" -NoTypeInformation
					Get-MEMCMDeviceCollectionMembers -CollectionId $CMObject.CollectionID -Source DEVICE | Select-Object Name, ResourceID, SMSID, AADDeviceID, SiteCode, ADLastLogonTime, ADSitename, BoundaryGroups, ClientActiveStatus, ClientVersion, CNAccessMP, CNIsOnInternet, CNLastOfflineTime, CNLastOnlineTime, CurrentLogonUser, DeviceOs, DeviceOSBuild, Domain, IsClient, IsActive, LastActiveTime, LastHardwareScan, LastLogonUser, LastMPServerName, MACAddress, PrimaryUser | Export-Csv -Path "filesystem::$CMObjectExportBasePath.Members.WMI_Device.csv" -NoTypeInformation
				}
				Pop-Location
				#compress archive
				$ArchiveFile = Join-Path -Path $(Split-Path -Path $ExportPath -Parent) -ChildPath "$(Remove-InvalidFileNameChars -Name "Collection $($CMObject.CollectionID) - $($CMObject.Name)").zip"
				#Remove existing export file since overwriting is not possible
				If (Test-Path -Path $ArchiveFile -PathType Leaf) { Remove-Item -Path $ArchiveFile -Force }
				Compress-Archive -Path "$ExportPath\*.*" -DestinationPath $ArchiveFile -CompressionLevel Optimal
				If (Test-Path -Path $ArchiveFile -PathType Leaf) { Remove-Item -Path "$ExportPath" -Recurse -Force }

			} catch {
				Write-LogMessage -Message "FAILED exporting ConfigMgr Collection object named [$($CMObject.Name)] to file [$ExportFile]" -Type Error -Component 'Export-CMCollection' -Console
			}
		}
		[void](Remove-Variable -Name CMObjects, CMObject, ExportFile -ErrorAction SilentlyContinue)
		Pop-Location
	} Catch {
		Write-LogMessage -Message "FAILED Exporting ConfigMgr Collections" -Type Error -Component 'Export-MECMCollection' -Console
	}
}
Function Export-MECMSecurityRoles {
	[CmdletBinding()] #(SupportsShouldProcess=$false, ConfirmImpact="Low")
	Param (
		[Parameter(Mandatory = $true)][string]$Path,
		[Parameter(Mandatory = $true)][ValidateLength(3, 3)][string]$SiteCode
	)
	Write-Verbose -Message 'Exporting ConfigMgr Security Roles...'
	Try {
		Push-Location -Path "$SiteCode`:"
		$CMObjects = Get-CMSecurityRole | Where-Object { $_.RoleId -notlike 'SMS*' }
		Write-LogMessage -Message "Found $($CMObjects.count) ConfigMgr Security Role objects to export" -Type Info -Component 'Export-MECMSecurityRoles'
		ForEach ($CMObject in $CMObjects) {
			$ExportFile = Join-Path -Path $Path -ChildPath "$(Remove-InvalidFileNameChars -Name $($CMObject.RoleName)).xml"
			If (Test-Path -Path $ExportFile -PathType Leaf) { Remove-Item -Path $ExportFile -Force }
			try {
				Export-CMSecurityRole -InputObject $CMObject -Path $ExportFile
				Write-LogMessage -Message "Exported ConfigMgr Security Role object named [$($CMObject.Name)] to file [$ExportFile]" -Type Info -Component 'Export-CMSecurityRole'
			} catch {
				Write-LogMessage -Message "Failed exporting ConfigMgr Security Role object named [$($CMObject.Name)] to file [$ExportFile]" -Type Error -Component 'Export-CMSecurityRole'
			}
		}
		Remove-Variable -Name CMObjects, CMObject, ExportFile -ErrorAction SilentlyContinue | Out-Null
		Pop-Location
	} Catch {}
}
Function Export-MECMWindowsEnrollmentProfiles {
	[CmdletBinding()] #(SupportsShouldProcess=$false, ConfirmImpact="Low")
	Param (
		[Parameter(Mandatory = $true)][string]$Path,
		[Parameter(Mandatory = $true)][ValidateLength(3, 3)][string]$SiteCode
	)
	Write-Verbose -Message 'Exporting ConfigMgr Windows Enrollment Profiles...'
	Try {
		Push-Location -Path "$SiteCode`:"
		$CMObjects = Get-CMWindowsEnrollmentProfile
		Write-LogMessage -Message "Found $($CMObjects.count) ConfigMgr Windows Enrollment Profile objects to export" -Type Info -Component 'Export-MECMWindowsEnrollmentProfiles'
		ForEach ($CMObject in $CMObjects) {
			$ExportFile = Join-Path -Path $Path -ChildPath "$(Remove-InvalidFileNameChars -Name $($CMObject.Name)).xml"
			If (Test-Path -Path $ExportFile -PathType Leaf) { Remove-Item -Path $ExportFile -Force }
			try {

				Export-CMWindowsEnrollmentProfile -InputObject $CMObject -Path $ExportFile
				Write-LogMessage -Message "Exported ConfigMgr Windows Enrollment Profile object named [$($CMObject.Name)] to file [$ExportFile]" -Type Info -Component 'Export-CMWindowsEnrollmentProfile'
			} catch {
				Write-LogMessage -Message "Failed exporting ConfigMgr Windows Enrollment Profile object named [$($CMObject.Name)] to file [$ExportFile]" -Type Error -Component 'Export-CMWindowsEnrollmentProfile'
			}
		}
		Remove-Variable -Name CMObjects, CMObject, ExportFile -ErrorAction SilentlyContinue | Out-Null
		Pop-Location
	} Catch {}
}
Function Export-MECMClientSettings {
	#.Synopsis Export ConfigMgr/SCCM object for import into a different ConfigMgr environment
	#.Notes
	#   2018/12/21 by Chad.Simmons@CatapultSystems.com - Created
	[CmdletBinding()] #(SupportsShouldProcess=$false, ConfirmImpact="Low")
	Param (
		[Parameter(Mandatory = $true)][string]$Path,
		[Parameter(Mandatory = $false, HelpMessage = 'Computer Fully Qualified Domain Name')][ValidateScript( { Resolve-DnsName -Name $_ })][string]$SiteServer,
		[Parameter(Mandatory = $true)][ValidateLength(3, 3)][string]$SiteCode
	)
	$CMObjectType = 'Client Settings'
	Write-Verbose -Message 'Exporting ConfigMgr CMObjectType objects...'
	Try {
		Write-Progress -Id 2 -Activity "Exporting ConfigMgr $CMObjectType" -Status 'Getting objects...'

		#Export Policy object
		$ExportFile = Join-Path -Path $Path -ChildPath 'ClientSettingsPolicies.csv'
		Push-Location -Path "$SiteCode`:"
		$CMObjects = Get-CMClientSetting
		Pop-Location
		Write-LogMessage -Message "Found $($CMObjects.count) ConfigMgr $CMObjectType objects to export" -Type Info -Component 'Export-MECMClientSettings'
		Push-Location -Path $env:SystemDrive
		$CMObjects | Export-Csv -Path $ExportFile -NoTypeInformation
		Pop-Location

		#ClientSettings Policy Deployments
		$ExportFile = Join-Path -Path $Path -ChildPath 'ClientSettingsPoliciesDeployments.csv'
		Write-LogMessage -Message "Found $($CMObjects.count) ConfigMgr $CMObjectType objects to export" -Type Info -Component 'Export-MECMClientSettings'
		Push-Location -Path $env:SystemDrive
		$CMObjects = Get-CimInstance -ComputerName $SiteServer -Namespace "root\SMS\Site_$($SiteCode)" -ClassName SMS_ClientSettingsAssignment
		$CMObjects | Select-Object ClientSettingsID, CollectionID, CollectionName | Export-Csv -Path $ExportFile -NoTypeInformation
		Pop-Location

		#ClientSettings Policy List
		$ExportFile = Join-Path -Path $Path -ChildPath 'ClientSettingsPoliciesList.csv'
		Write-LogMessage -Message "Found $($CMObjects.count) ConfigMgr $CMObjectType objects to export" -Type Info -Component 'Export-MECMClientSettings'
		Push-Location -Path $env:SystemDrive
		$CMObjects = Get-CimInstance -ComputerName $SiteServer -Namespace "root\SMS\Site_$($SiteCode)" -ClassName SMS_ClientSettings
		$CMObjects | Select-Object Name, Priority, Description, SettingsID, Type, SecuredScopeNames | Export-Csv -Path $ExportFile -NoTypeInformation
		#TODO: ensure all scopes are listed $ExportFile = "$ExportPathRoot\ClientSettingsPoliciesListScopes.csv"
		Pop-Location

		$ExportFile = Join-Path -Path $Path -ChildPath 'ClientSettingsDetails.csv'
		$reportAll = @()
		Push-Location -Path "$SiteCode`:"
		# Get the different Client settings Names
		ForEach ($a in $($CMObjects | Select-Object Name)) {
			Write-Progress -Status "Exporting ConfigMgr Client Settings" -Activity "Exporting policy $($a.Name)"
			# Get all possible values for the Get-CMClientSetting -Setting parameter
			$xSettings = [Enum]::GetNames( [Microsoft.ConfigurationManagement.Cmdlets.ClientSettings.Commands.SettingType])
			# dump the detailed configuration settings
			ForEach ($xSetting in $xSettings ) {
				$CMClientSettings = Get-CMClientSetting -Setting $xSetting -Name $a.Name
				if ($CMClientSettings.count -gt 0) {
					$CMClientSettings.GetEnumerator() | ForEach-Object {
						$CMClientSettingsObj = New-Object PSObject -Property ([ordered]@{
								"Client Setting" = $a.Name;
								"Type"           = $xSetting;
								"Key"            = $_.Key;
								"Value"          = $_.Value;
							})
						$reportAll += $CMClientSettingsObj
					}
				}
			}
		}
		Pop-Location
		$reportAll | Export-Csv -Path $ExportFile -NoTypeInformation
	} Catch {}
	Write-LogMessage -Message "$CMobjectType object export complete" -Type Info -Component 'Export-MECMClientSettings'
	Write-Progress -Id 2 -Activity "Exporting ConfigMgr $CMObjectType" -Status 'Complete' -Completed
}
Function Export-MECMTaskSequences {
	[CmdletBinding()] #(SupportsShouldProcess=$false, ConfirmImpact="Low")
	Param (
		[Parameter(Mandatory = $true)][string]$Path,
		[Parameter(Mandatory = $true, HelpMessage = 'Computer Fully Qualified Domain Name')][ValidateScript( { Resolve-DnsName -Name $_ })][string]$SiteServer,
		[Parameter(Mandatory = $true, HelpMessage = 'ConfigMgr Site Code')][ValidateLength(3, 3)][string]$SiteCode,
		[Parameter()][bool]$WithDependencies = $true,
		[Parameter()][bool]$WithContent = $false
	)
	#.Synopsis
	#   Export-CMTaskSequenceInFormattedXML.ps1
	#   Export ConfigMgr Task Sequences in XML format, witout Dependencies, and optionally with Dependencies and with Content
	#.Link
	#   https://kelleymd.wordpress.com/2015/01/10/export-a-task-sequence-in-xml-format/
	#Get the Task Sequence base class in order to call its static methods
	Write-Verbose -Message 'Exporting ConfigMgr Task Sequences...'
	$TaskSequenceClass = [wmiclass]"\\$SiteServer\root\sms\site_$($SiteCode):sms_tasksequence"
	Push-Location -Path "$SiteCode`:"
	$CMObjects = Get-CMTaskSequence
	Write-LogMessage -Message "Found $($CMObjects.count) ConfigMgr Task Sequence objects to export" -Type Info -Component 'Export-MECMTaskSequences'
	$CMObjects | Select-Object PackageID, Name, ReferencesCount, Type, Description | Export-Csv -Path "$Path\TaskSequence List.csv" -NoTypeInformation -Force
	ForEach ($CMObject in $CMObjects) {
		#Save the XML
		Try {
			$TaskSequence = [wmi]"\\$SiteServer\root\sms\site_$($SiteCode):sms_tasksequencepackage.packageID='$($CMObject.PackageID)'"
			$ExportFile = Join-Path -Path $Path -ChildPath "TaskSequence-$($TaskSequence.PackageID) ($($TaskSequence.Name)).xml"
			If (Test-Path -Path $ExportFile -PathType Leaf) { Remove-Item -Path $ExportFile -Force }
			#Debug: $TaskSequence | Select PackageID, Name, ReferencesCount, Type, Description | Format-List
			#call the export XML method from the Task Sequence class and call the save method to write the file
			([xml]$TaskSequenceClass.ExportXml($TaskSequence.Sequence).returnvalue).Save($ExportFile)
			Write-LogMessage -Type Info -Message "Exported Task Sequence $($TaskSequence.Name) to file [$ExportFile]" -Component 'Export-MECMTaskSequenceAsXML'
		} Catch {
			Write-LogMessage -Type Error -Message "Failed exporting Task Sequence $($TaskSequence.Name) to file [$ExportFile]" -Component 'Export-MECMTaskSequenceAsXML'
		}
		Remove-Variable -Name TaskSequence, ExportFile -ErrorAction SilentlyContinue | Out-Null

		#Export Task Sequences
		Try {
			$ExportFile = Join-Path -Path $Path -ChildPath "$($CMObject.Name).zip"
			If (Test-Path -Path $ExportFile -PathType Leaf) { Remove-Item -Path $ExportFile -Force }
			Export-CMTaskSequence -PackageID $CMObject.PackageID -ExportFilePath $ExportFile -WithDependence $false -WithContent $false
			Write-LogMessage -Type Info -Message "Exported Task Sequence [$($CMObject.Name)] without Dependencies to file [$ExportFile]" -Component 'Export-MECMTaskSequence'
		} Catch {
			Write-LogMessage -Type Error -Message "Failed exporting Task Sequence [$($CMObject.Name)] without Dependencies to file [$ExportFile]" -Component 'Export-MECMTaskSequence'
		}
		Remove-Variable -Name ExportFile -ErrorAction SilentlyContinue | Out-Null

		If ($WithDependencies) {
			Try {
				$ExportFile = Join-Path -Path $Path -ChildPath "$($CMObject.Name) (with dependencies).zip"
				If (Test-Path -Path $ExportFile -PathType Leaf) { Remove-Item -Path $ExportFile -Force }
				Export-CMTaskSequence -PackageID $($CMObject.PackageID) -ExportFilePath $ExportFile -WithDependence $true -WithContent $false
				Write-LogMessage -Type Info -Message "Exported Task Sequence [$($CMObject.Name)] with Dependencies to file [$ExportFile]" -Component 'Export-MECMTaskSequence'
			} Catch {
				Write-LogMessage -Type Error -Message "Failed exporting Task Sequence [$($CMObject.Name)] with Dependencies to file [$ExportFile]" -Component 'Export-MECMTaskSequence'
			}
		}
		Remove-Variable -Name ExportFile -ErrorAction SilentlyContinue | Out-Null

		If ($WithContent) {
			Try {
				$ExportFile = Join-Path -Path $Path -ChildPath "$($CMObject.Name) (with content).zip"
				If (Test-Path -Path $ExportFile -PathType Leaf) { Remove-Item -Path $ExportFile -Force }
				Export-CMTaskSequence -PackageID $($CMObject.PackageID) -ExportFilePath $ExportFile -WithDependence $true -WithContent $true
				Write-LogMessage -Type Info -Message "Exported Task Sequence [$($CMObject.Name)] with Dependencies and Content to file [$ExportFile]" -Component 'Export-MECMTaskSequence'
			} Catch {
				Write-LogMessage -Type Error -Message "Failed exporting Task Sequence [$($CMObject.Name)] with Dependencies and Content to file [$ExportFile]" -Component 'Export-MECMTaskSequence'
			}
		}
		Remove-Variable -Name ExportFile -ErrorAction SilentlyContinue | Out-Null
	}
	Remove-Variable -Name CMObjects, CMObject -ErrorAction SilentlyContinue | Out-Null
	Pop-Location
}
Function Export-MECMPackages {
	[CmdletBinding()] #(SupportsShouldProcess=$false, ConfirmImpact="Low")
	Param (
		[Parameter(Mandatory = $true)][string]$Path,
		[Parameter(Mandatory = $true)][ValidateLength(3, 3)][string]$SiteCode,
		[Parameter()][bool]$WithContent = $false,
		[Parameter()][bool]$WithDependence = $false
	)
	Write-Verbose -Message 'Exporting ConfigMgr Packages...'
	Try {
		Push-Location -Path "$SiteCode`:"
		$CMObjects = Get-CMPackage #| Select-Object PackageID, Manufacturer, Name, Version, Description
		Write-LogMessage -Message "Found $($CMObjects.count) ConfigMgr Package objects to export" -Type Info -Component 'Export-MECMPackage'
		$CMObjects | Select-Object PackageID, Manufacturer, Name, Version, Description | Export-Csv -Path "$Path\Packages List.csv" -NoTypeInformation
		#TODO: add additional properties such as content source path
		ForEach ($CMObject in $CMObjects) {
			$pkgName = "$($CMObject.Manufacturer) $($CMObject.Name) $($CMObject.Version)".Trim()
			$ExportFile = Join-Path -Path $Path -ChildPath "$(Remove-InvalidFileNameChars -Name $($pkgName)).zip"
			If (Test-Path -Path $ExportFile -PathType Leaf) { Remove-Item -Path $ExportFile -Force }
			try {
				Export-CMPackage -InputObject $CMObject -FileName $ExportFile -WithContent $false -WithDependence $WithDependence
				Write-LogMessage -Message "Exported ConfigMgr Package object named [$($CMObject.Name)] to file [$ExportFile]" -Type Info -Component 'Export-CMPackage'
			} catch {
				Write-LogMessage -Message "Failed exporting ConfigMgr Package object named [$($CMObject.Name)] to file [$ExportFile]" -Type Error -Component 'Export-CMPackage'
			}
			If ($WithContent) {
				$pkgName = "$($CMObject.Manufacturer) $($CMObject.Name) $($CMObject.Version) (with content)".Trim()
				$ExportFile = Join-Path -Path $Path -ChildPath "$(Remove-InvalidFileNameChars -Name $($pkgName)).zip"
				If (Test-Path -Path $ExportFile -PathType Leaf) { Remove-Item -Path $ExportFile -Force }
				try {
					Export-CMPackage -InputObject $CMObject -FileName $ExportFile -WithContent $true -WithDependence $WithDependence
					Write-LogMessage -Message "Exported ConfigMgr Package object named [$($CMObject.Name)] to file [$ExportFile]" -Type Info -Component 'Export-CMPackage'
				} catch {
					Write-LogMessage -Message "Failed exporting ConfigMgr Package object named [$($CMObject.Name)] to file [$ExportFile]" -Type Error -Component 'Export-CMPackage'
				}
			}
			Remove-Variable -Name ExportFile, pkgName -ErrorAction SilentlyContinue | Out-Null
		}
		Remove-Variable -Name CMObjects, CMObject -ErrorAction SilentlyContinue | Out-Null
		Pop-Location
	} Catch {}
}
Function Export-MECMDriverPackages {
	[CmdletBinding()] #(SupportsShouldProcess=$false, ConfirmImpact="Low")
	Param (
		[Parameter(Mandatory = $true)][string]$Path,
		[Parameter(Mandatory = $true)][ValidateLength(3, 3)][string]$SiteCode,
		[Parameter()][bool]$WithDependencies = $true,
		[Parameter()][bool]$WithContent = $false
	)
	Write-Verbose -Message 'Exporting ConfigMgr Driver Packages ...'
	Try {
		Push-Location -Path "$SiteCode`:"
		$CMObjects = Get-CMDriverPackage
		Write-LogMessage -Message "Found $($CMObjects.count) ConfigMgr Driver Package objects to export" -Type Info -Component 'Export-MECMDriverPackages'
		ForEach ($CMObject in $CMObjects) {
			Try {
				$ExportFile = Join-Path -Path $Path -ChildPath "$($CMObject.Name).zip"
				If (Test-Path -Path $ExportFile -PathType Leaf) { Remove-Item -Path $ExportFile -Force }
				Export-CMDriverPackage -InputObject $CMObject -ExportFilePath $ExportFile -Comment $CMObject.Comment -WithDependence $false -WithContent $false
				Write-LogMessage -Type Info -Message "Exported Driver Package [$($CMObject.Name)] without Dependencies to file [$ExportFile]" -Component 'Export-CMDriverPackage'
			} Catch {
				Write-LogMessage -Type Error -Message "Failed exporting Driver Package [$($CMObject.Name)] without Dependencies to file [$ExportFile]" -Component 'Export-CMDriverPackage'
			}
			Remove-Variable -Name ExportFile -ErrorAction SilentlyContinue | Out-Null

			If ($WithDependencies) {
				Try {
					$ExportFile = Join-Path -Path $Path -ChildPath "$($CMObject.Name) (with dependencies).zip"
					If (Test-Path -Path $ExportFile -PathType Leaf) { Remove-Item -Path $ExportFile -Force }
					Export-CMDriverPackage -PackageID $($CMObject.PackageID) -ExportFilePath $ExportFile -Comment $CMObject.Comment -WithDependence $true -WithContent $false
					Write-LogMessage -Type Info -Message "Exported Driver Package [$($CMObject.Name)] with Dependencies to file [$ExportFile]" -Component 'Export-CMDriverPackage'
				} Catch {
					Write-LogMessage -Type Error -Message "Failed exporting Driver Package [$($CMObject.Name)] with Dependencies to file [$ExportFile]" -Component 'Export-CMDriverPackage'
				}
			}
			Remove-Variable -Name ExportFile -ErrorAction SilentlyContinue | Out-Null

			If ($WithContent) {
				Try {
					$ExportFile = Join-Path -Path $Path -ChildPath "$($CMObject.Name) (with content).zip"
					If (Test-Path -Path $ExportFile -PathType Leaf) { Remove-Item -Path $ExportFile -Force }
					Export-CMDriverPackage -PackageID $($CMObject.PackageID) -ExportFilePath $ExportFile -Comment $CMObject.Comment -WithDependence $true -WithContent $true
					Write-LogMessage -Type Info -Message "Exported Driver Package [$($CMObject.Name)] with Dependencies and Content to file [$ExportFile]" -Component 'Export-CMDriverPackage'
				} Catch {
					Write-LogMessage -Type Error -Message "Failed exporting Driver Package [$($CMObject.Name)] with Dependencies and Content to file [$ExportFile]" -Component 'Export-CMDriverPackage'
				}
			}
			Remove-Variable -Name ExportFile -ErrorAction SilentlyContinue | Out-Null
		}
		Remove-Variable -Name CMObjects, CMObject -ErrorAction SilentlyContinue | Out-Null
		Pop-Location
	} Catch {}
}
Function Export-MECMApplications {
	#.Synopsis Export ConfigMgr/SCCM Application objects for import into a different ConfigMgr environment
	#.Notes
	#   2018/12/21 by Chad.Simmons@CatapultSystems.com - Created
	[CmdletBinding()] #(SupportsShouldProcess=$false, ConfirmImpact="Low")
	Param (
		[Parameter(Mandatory = $true)][string]$Path,
		[Parameter(Mandatory = $true)][ValidateLength(3, 3)][string]$SiteCode,
		[Parameter()][bool]$WithDependencies = $true,
		[Parameter()][bool]$WithContent = $false
	)
	$CMObjectType = 'Application'
	Try {
		Write-Progress -Id 2 -Activity "Exporting ConfigMgr $CMObjectType" -Status 'Getting objects...'
		Push-Location -Path "$SiteCode`:"
		$CMObjects = Get-CMApplication
		Write-LogMessage -Message "Found $($CMObjects.count) ConfigMgr $CMObjectType objects to export" -Type Info -Component 'Export-MECMApplications'
		$i = 0
		ForEach ($CMObject in $CMObjects) {
			$i++
			$CMObjectName = ("$($CMObject.Manufacturer) $($CMObject.LocalizedDisplayName) $($CMObject.SoftwareVersion)").Trim()
			Write-Progress -Id 2 -Activity "Exporting ConfigMgr $CMObjectType" -Status "[$i of $($CMObjects.Count)] $CMObjectName" -PercentComplete $($($i / $($CMObjects.Count)) * 100)
			Try {
				$ExportFile = Join-Path -Path $Path -ChildPath "$CMObjectName.zip"
				If (Test-Path -Path $ExportFile -PathType Leaf) { Remove-Item -Path $ExportFile -Force }
				Export-CMApplication -InputObject $CMObject -Path $ExportFile -IgnoreRelated -OmitContent -Comment $CMObjectName
				Write-LogMessage -Type Info -Message "Exported Application [$CMObjectName)] without Dependencies to file [$ExportFile]" -Component 'Export-CMApplication'
			} Catch {
				Write-LogMessage -Type Error -Message "Failed exporting Application [$CMObjectName)] without Dependencies to file [$ExportFile]" -Component 'Export-CMApplication'
			}
			Remove-Variable -Name ExportFile -ErrorAction SilentlyContinue | Out-Null

			If ($WithDependencies) {
				Write-Progress -Id 2 -Activity "Exporting ConfigMgr $CMObjectType" -Status "[$i of $($CMObjects.Count)] $CMObjectName" -CurrentOperation 'exporting with dependencies' -PercentComplete $($($i / $($CMObjects.Count)) * 100)
				Try {
					$ExportFile = Join-Path -Path $Path -ChildPath "$CMObjectName (with dependencies).zip"
					If (Test-Path -Path $ExportFile -PathType Leaf) { Remove-Item -Path $ExportFile -Force }
					Export-CMApplication -InputObject $CMObject -Path $ExportFile -OmitContent -Comment $CMObjectName
					Write-LogMessage -Type Info -Message "Exported Application [$CMObjectName] with Dependencies to file [$ExportFile]" -Component 'Export-CMApplication'
				} Catch {
					Write-LogMessage -Type Error -Message "Failed exporting Application [$CMObjectName] with Dependencies to file [$ExportFile]" -Component 'Export-CMApplication'
				}
				Remove-Variable -Name ExportFile -ErrorAction SilentlyContinue | Out-Null
			}

			If ($WithContent) {
				Write-Progress -Id 2 -Activity "Exporting ConfigMgr $CMObjectType" -Status "[$i of $($CMObjects.Count)] $CMObjectName" -CurrentOperation 'exporting with dependencies and content' -PercentComplete $($($i / $($CMObjects.Count)) * 100)
				Try {
					$ExportFile = Join-Path -Path $Path -ChildPath "$CMObjectName (with content).zip"
					If (Test-Path -Path $ExportFile -PathType Leaf) { Remove-Item -Path $ExportFile -Force }
					Export-CMApplication -InputObject $CMObject -Path $ExportFile -Comment $CMObjectName
					Write-LogMessage -Type Info -Message "Exported Application [$CMObjectName] with Dependencies and Content to file [$ExportFile]" -Component 'Export-CMApplication'
				} Catch {
					Write-LogMessage -Type Error -Message "Failed exporting Application [$CMObjectName] with Dependencies and Content to file [$ExportFile]" -Component 'Export-CMApplication'
				}
				Remove-Variable -Name ExportFile -ErrorAction SilentlyContinue | Out-Null
			}
			Remove-Variable -Name CMObjectName -ErrorAction SilentlyContinue | Out-Null
		}
		Remove-Variable -Name CMObjects, CMObject -ErrorAction SilentlyContinue | Out-Null
		Pop-Location
	} Catch {}
	Write-LogMessage -Message "$CMobjectType object export complete" -Type Info -Component 'Export-MECMApplications'
	Write-Progress -Id 2 -Activity "Exporting ConfigMgr $CMObjectType" -Status 'Complete' -Completed
}
Function Export-MECMScripts {
	#.Synopsis Export ConfigMgr/SCCM Scripts for import into a different ConfigMgr environment
	#.Notes
	#   2020/10/16 by Chad.Simmons@CatapultSystems.com - Created
	[CmdletBinding()] #(SupportsShouldProcess=$false, ConfirmImpact="Low")
	Param (
		[Parameter(Mandatory = $true)][string]$Path,
		[Parameter(Mandatory = $false)][ValidateLength(3, 3)][string]$SiteCode = $SiteCode,
		[Parameter(Mandatory = $false)][string]$SiteServer = $SiteServer
	)
	$CMObjectType = 'CMScripts'
	Write-Verbose -Message 'Exporting ConfigMgr CMObjectType objects...'
	Try {
		Write-Progress -Id 2 -Activity "Exporting ConfigMgr $CMObjectType" -Status 'Getting objects...'
		$CMObjects = Get-WmiObject -Namespace ROOT\SMS\site_$SiteCode -ComputerName $SiteServer -Class SMS_Scripts
		Write-LogMessage -Message "Found $($CMObjects.count) ConfigMgr $CMObjectType objects to export" -Type Info -Component 'MECMScripts'
		$i = 0
		ForEach ($CMObject in $CMObjects) {
			$i++
			$CMObjectName = $CMObject.ScriptName
			Write-Progress -Id 2 -Activity "Exporting ConfigMgr $CMObjectType" -Status "[$i of $($CMObjects.Count)] $CMObjectName" -PercentComplete $($($i / $($CMObjects.Count)) * 100)
			#Exclude scripts with feature set to 1. These are system scripts like CMPivot.
			if (($CMObject.Feature -ne 1)) {
				$CMObject.Get()
				$ScriptText = ([System.Text.Encoding]::unicode.GetString([System.Convert]::FromBase64String($($CMObject.Script)))).Substring(1)
				$ExportFile = Join-Path -Path $Path -ChildPath "$(Remove-InvalidFileNameChars -Name $CMObjectName).extension"
				If (Test-Path -Path $ExportFile -PathType Leaf) { Remove-Item -Path $ExportFile -Force }
				try {
					$ScriptText | Out-File -FilePath $ExportFile
					Write-LogMessage -Message "Exported ConfigMgr $CMObjectType object named [$CMObjectName] to file [$ExportFile]" -Type Info -Component 'MECMScripts'
				} catch {
					Write-LogMessage -Message "Failed exporting ConfigMgr $CMObjectType object named [$CMObjectName] to file [$ExportFile]" -Type Error -Component 'MECMScripts'
				}
			}
			Remove-Variable -Name CMObjects, CMObject, CMObjectName, ExportFile -ErrorAction SilentlyContinue | Out-Null
		}
	} Catch {}
	Write-LogMessage -Message "$CMobjectType object export complete" -Type Info -Component 'MECMScripts'
	Write-Progress -Id 2 -Activity "Exporting ConfigMgr $CMObjectType" -Status 'Complete' -Completed
}

Function Export-MECMxyz {
	#.Synopsis Export ConfigMgr/SCCM object for import into a different ConfigMgr environment
	#.Notes
	#   2018/12/21 by Chad.Simmons@CatapultSystems.com - Created
	[CmdletBinding()] #(SupportsShouldProcess=$false, ConfirmImpact="Low")
	Param (
		[Parameter(Mandatory = $true)][string]$Path,
		[Parameter(Mandatory = $false)][ValidateLength(3, 3)][string]$SiteCode = $SiteCode,
		[Parameter(Mandatory = $false)][string]$SiteServer = $SiteServer
	)
	$CMObjectType = 'Application'
	Write-Verbose -Message 'Exporting ConfigMgr CMObjectType objects...'
	Try {
		Write-Progress -Id 2 -Activity "Exporting ConfigMgr $CMObjectType" -Status 'Getting objects...'
		Push-Location -Path "$SiteCode`:"
		$CMObjects = Get-CM___
		Write-LogMessage -Message "Found $($CMObjects.count) ConfigMgr $CMObjectType objects to export" -Type Info -Component 'Export-MECM___'
		$i = 0
		ForEach ($CMObject in $CMObjects) {
			$i++
			$CMObjectName = ("????").Trim()
			Write-Progress -Id 2 -Activity "Exporting ConfigMgr $CMObjectType" -Status "[$i of $($CMObjects.Count)] $CMObjectName" -PercentComplete $($($i / $($CMObjects.Count)) * 100)
			$ExportFile = Join-Path -Path $Path -ChildPath "$(Remove-InvalidFileNameChars -Name $CMObjectName).extension"
			If (Test-Path -Path $ExportFile -PathType Leaf) { Remove-Item -Path $ExportFile -Force }
			try {
				Export-CM___ -InputObject $CMObject -Path $ExportFile
				Write-LogMessage -Message "Exported ConfigMgr $CMObjectType object named [$CMObjectName] to file [$ExportFile]" -Type Info -Component 'Export-CM___'
			} catch {
				Write-LogMessage -Message "Failed exporting ConfigMgr $CMObjectType object named [$CMObjectName] to file [$ExportFile]" -Type Error -Component 'Export-CM___'
			}
		}
		Remove-Variable -Name CMObjects, CMObject, CMObjectName, ExportFile -ErrorAction SilentlyContinue | Out-Null
		Pop-Location
	} Catch {}
	Write-LogMessage -Message "$CMobjectType object export complete" -Type Info -Component 'Export-MECM___'
	Write-Progress -Id 2 -Activity "Exporting ConfigMgr $CMObjectType" -Status 'Complete' -Completed
}



################################################################################
################################################################################
#endregion ######################### Functions #################################


#region    ######################### Initialization ############################
If (-not(Test-Path -Path $ExportPathRoot)) {
	Push-Location $env:SystemDrive
	[void](New-Item -Path $ExportPathRoot -ItemType Directory -Force)
	Pop-Location
}

Get-ScriptInfo -FullPath $(If (Test-Path -LiteralPath 'variable:HostInvocation') { $HostInvocation.MyCommand.Definition } Else { $MyInvocation.MyCommand.Definition })
$script:LogFile = "$ExportPathRoot\$ScriptBaseName.log"
Write-LogMessage -Message "==================== Starting script [$ScriptFullPath] at $($ScriptStartTime.ToString('F')) ===================="; Write-LogMessage -Message "Logging to file [$script:LogFile]" -Console
If ($WhatIfPreference) { Write-LogMessage -Message "     ========== Running with WhatIf.  NO ACTUAL CHANGES are expected to be made! ==========" -Type Warn }

Connect-ConfigMgr -SiteCode $SiteCode -SiteServer $SiteServer
#endregion ######################### Initialization ############################
#region    ######################### Main Script ###############################

#region    === DONE
#DONE: CMAntimalwarePolicy
#DONE: CMPackage
#DONE: CMQuery
#DONE: CMTaskSequence
#DONE: CMSoftwareMeteringRule
#DONE: CMConfigurationItem
#DONE: CMBaseline
#DONE: CMCollection
#DONE: CMSecurityRole
#DONE: CMDriverPackage
#DONE: CMWindowsEnrollmentProfile
#DONE: CMApplication
#DONE: CMScripts
#DONE: Client Settings
#DONE (External script): Status Message Queries (custom and customized)
#DONE (External script): Reports
#endregion === DONE
#region    === #TODO: Additional objects to export
#Folders
#Folders with object IDs
#? Users (including variables, etc.)
#? User Groups (including variables, etc.)
#? Devices (including variables, etc.)
#User State Migration
#User Data Profiles
#Remote Connection Profiles
#Compliance Policies
#Compliance Notification Templates
#Conditional Access Policy from On-Premises Exchanges
#Certificate Profiles
#Email Profiles
#VPN Profiles
#Wi-Fi Profiles
#Windows Hello for Business Profiles
#Terms and Conditions
#Windows 10 Edition Upgrades
#Microsoft Edge Browser Profiles
#Windows Defender Firewall Policies
#Windows Defender ATP Policies
#Windows Defender Exploit Guard
#Windows Defender Application Guard
#Predeclared Devices
#iOS Enrollment Profiles
#Windows Enrollment Profiles
#Windows Enrollment Packages
#License Information for Store Apps
#Approval Requests
#Global Conditions
#App-V Virtual Environments
#Windows Sideloading Keys
#Application Management Policies
#App Configuration Policies
#Software Updates with Custom Severity
#Software Update Groups
#Software Update Groups with membership
#Automatic Deployment Rules
#Third-Party Software Update Catalogs
#Drivers
#Operating System Images
#Operating System Upgrade Packages
#Boot Images
#Windows 10 Servicing Plans
#Windows Update for Business Policies
#Alerts
#Subscriptions
#Report Subscriptions
#Deployments
#Status Message Filter Rules
#Security Scopes
#Certificates
#Export results of various reports including Users, Devices with inventory, collection membership, maintenance windows, etc.
#endregion === #Additional objects to export

If ('StatusMessageQuery' -in $ObjectTypes -or $null -eq $ObjectTypes -or $ObjectTypes -eq 'All') {
	$ExternalScript = Join-Path -Path $ScriptPath -ChildPath 'Export-MECMStatusMessageQuery.ps1'
	If (Test-Path -Path $ExternalScript -PathType Leaf) {
		& $ExternalScript -Force -Recurse -SiteServer $SiteServer -Path $(Join-Path -Path $ExportPathRoot -ChildPath 'SCCMStatusMessageQuery.xml')
	}
}
If ('SSRSReports' -in $ObjectTypes -or $null -eq $ObjectTypes -or $ObjectTypes -eq 'All') {
	$ExportPath = New-ExportPath -RootPath $ExportPathRoot -Path 'SSRS Reports'
	$ExternalScript = Join-Path -Path $ScriptPath -ChildPath 'Backup-SQLReportingServicesFiles.ps1'
	If (Test-Path -Path $ExternalScript -PathType Leaf) {
		& $ExternalScript -ReportServer $SiteServer -BackupPath $ExportPath -LogPath $ExportPathRoot -ArchiveBaseName "SSRSReportsAndSettings_" #-PasswordEncoded 'UwAkAFIANQBfADQAIABGAEgATABCAGQAYQBsAGwAYQBzAC0AQwBvAG4AZgBpAGcATQBnAHIA' #Base64 Unicode
	}
}
If ('SoftwareMeteringRules' -in $ObjectTypes -or $null -eq $ObjectTypes -or $ObjectTypes -eq 'All') {
	Export-MECMSoftwareMeteringRules -Path $ExportPathRoot -SiteCode $SiteCode
}
If ('ClientSettings' -in $ObjectTypes -or $null -eq $ObjectTypes -or $ObjectTypes -eq 'All') {
	Export-MECMClientSettings -Path $ExportPathRoot -SiteCode $SiteCode
}
If ('WindowsEnrollmentProfiles' -in $ObjectTypes -or $null -eq $ObjectTypes -or $ObjectTypes -eq 'All') {
	$ExportPath = New-ExportPath -RootPath $ExportPathRoot -Path 'Windows Enrollment Profiles'
	Export-MECMWindowsEnrollmentProfiles -Path $ExportPath -SiteCode $SiteCode
}
If ('SecurityRoles' -in $ObjectTypes -or $null -eq $ObjectTypes -or $ObjectTypes -eq 'All') {
	$ExportPath = New-ExportPath -RootPath $ExportPathRoot -Path 'SecurityRoles'
	Export-MECMSecurityRoles -Path $ExportPath -SiteCode $SiteCode
}
If ('Collections' -in $ObjectTypes -or $null -eq $ObjectTypes -or $ObjectTypes -eq 'All') {
	$ExportPath = New-ExportPath -RootPath $ExportPathRoot -Path 'Collections'
	Export-MECMCollections -Path $ExportPath -SiteCode $SiteCode #-CollectionID CM100383
}
If ('ConfigurationItems' -in $ObjectTypes -or $null -eq $ObjectTypes -or $ObjectTypes -eq 'All') {
	$ExportPath = New-ExportPath -RootPath $ExportPathRoot -Path 'ConfigurationItems'
	Export-MECMConfigurationItems -Path $ExportPath -SiteCode $SiteCode
}
If ('Baselines' -in $ObjectTypes -or $null -eq $ObjectTypes -or $ObjectTypes -eq 'All') {
	$ExportPath = New-ExportPath -RootPath $ExportPathRoot -Path 'Baselines'
	Export-MECMBaselines -Path $ExportPath -SiteCode $SiteCode
}
If ('Queries' -in $ObjectTypes -or $null -eq $ObjectTypes -or $ObjectTypes -eq 'All') {
	$ExportPath = New-ExportPath -RootPath $ExportPathRoot -Path 'Queries'
	Export-MECMQueries -Path $ExportPath -SiteCode $SiteCode
}
If ('AntimalwarePolicies' -in $ObjectTypes -or $null -eq $ObjectTypes -or $ObjectTypes -eq 'All') {
	$ExportPath = New-ExportPath -RootPath $ExportPathRoot -Path 'AntimalwarePolicies'
	Export-MECMAntimalwarePolicies -Path $ExportPath -SiteCode $SiteCode
}
If ('Packages' -in $ObjectTypes -or $null -eq $ObjectTypes -or $ObjectTypes -eq 'All') {
	$ExportPath = New-ExportPath -RootPath $ExportPathRoot -Path 'Packages'
	Export-MECMPackages -Path $ExportPath -SiteCode $SiteCode -WithContent $WithContent
}
If ('Applications' -in $ObjectTypes -or $null -eq $ObjectTypes -or $ObjectTypes -eq 'All') {
	$ExportPath = New-ExportPath -RootPath $ExportPathRoot -Path 'Applications'
	Export-MECMApplications -Path $ExportPath -SiteCode $SiteCode -WithDependencies $WithDependencies -WithContent $WithContent
}
If ('DriverPackages' -in $ObjectTypes -or $null -eq $ObjectTypes -or $ObjectTypes -eq 'All') {
	$ExportPath = New-ExportPath -RootPath $ExportPathRoot -Path 'Driver Packages'
	Export-MECMDriverPackages -Path $ExportPath -SiteCode $SiteCode -WithDependencies $WithDependencies -WithContent $WithContent
}
If ('TaskSequences' -in $ObjectTypes -or $null -eq $ObjectTypes -or $ObjectTypes -eq 'All') {
	$ExportPath = New-ExportPath -RootPath $ExportPathRoot -Path 'Task Sequences'
	Export-MECMTaskSequences -Path $ExportPath -SiteCode $SiteCode -SiteServer $SiteServer -WithDependencies $WithDependencies -WithContent $WithContent
}
If ('CMScripts' -in $ObjectTypes -or $null -eq $ObjectTypes -or $ObjectTypes -eq 'All') {
	$ExportPath = New-ExportPath -RootPath $ExportPathRoot -Path 'CMScripts'
	Export-MECMScripts -Path $ExportPath -SiteCode $SiteCode -SiteServer $SiteServer
}

##region    ####### ConfigMgr Administrative users #####################################################################>
#$SiteCode = 'CM1'; $SiteServer = 'SCCM12.ati.corp.com'
#$ExportFile = 'C:\DataLocal\MEMCMAdminUsers.csv'
#Push-Location -Path "$SiteCode`:"
#$CMAdminUsers = Get-CMAdministrativeUser | Select-Object LogonName, IsGroup
#Pop-Location
#$CMAdminUserList = @()
#ForEach ($CMAdminUser in $CMAdminUsers) {
#	Write-Output $CMAdminUser.LogonName
#	If ($CMAdminUser.IsGroup -eq $true) {
#		$CMAdminUserIDs = (Get-WmiObject -ComputerName $SiteServer -Namespace "root\SMS\site_$($SiteCode)" -Query "Select UniqueUserName from SMS_R_User where UserGroupName like `"$($CMAdminUser.LogonName.replace('\','\\'))`"").UniqueUserName
#	} Else {
#		$CMAdminUserIDs = (Get-WmiObject -ComputerName $SiteServer -Namespace "root\SMS\site_$($SiteCode)" -Query "Select * from SMS_R_User where UniqueUserName = `"$($CMAdminUser.LogonName.replace('\','\\'))`"").UniqueUserName
#	}
#	ForEach ($CMAdminUserID in $CMAdminUserIDs) {
#		$CMAdminUserList += @(Get-WmiObject -ComputerName $SiteServer -Namespace "root\SMS\site_$($SiteCode)" -Query "Select * from SMS_R_User where UniqueUserName = `"$($CMAdminUserID.replace('\','\\'))`"" | Select-Object @{N = 'Group'; E = { $CMAdminUser.LogonName } }, UniqueUserName, ResourceID, ResourceType, UserName, Name, displayname, WindowsNTDomain, distinguishedName, FullDomainName, FullUserName, UserPrincipalName, mail, mobile, telephoneNumber, UserGroupName)
#	}
#}
#$CMAdminUserList | Select-Object Group, UniqueUserName, ResourceID, ResourceType, UserName, Name, displayname, WindowsNTDomain, distinguishedName, FullDomainName, FullUserName, UserPrincipalName, mail, mobile, telephoneNumber | Export-Csv -Path "filesystem::$($ExportFile)" -NoTypeInformation
#Write-Output "Exported $($CMAdminUserList.Count) users to $ExportFile"
##endregion ####### ConfigMgr Administrative users #####################################################################>


#endregion ######################### Main Script ###############################
#region    ######################### Deallocation ##############################
If ($WhatIfPreference) { Write-LogMessage -Message "     ========== Running with WhatIf.  NO ACTUAL CHANGES are expected to be made! ==========" -Type Warn }
Write-LogMessage -Message "==================== Completed script [$ScriptFullPath] at $(Get-Date -Format 'F') ====================" -Console
#endregion ######################### Deallocation ##############################