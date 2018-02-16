################################################################################
#.SYNOPSIS
#   Set-SCCMSoftwareUpdateMaximumExecutionTime.ps1
#   Increase the Maximum Run Time for Win10/WS2016 patches
#.DESCRIPTION
#   This tweak is needed to prevent ConfigMgr/SCCM/WUA/CBS/WSUS Error 0x800f0821 / 0x87D0070C - Software Update Timeout
#.PARAMETER <name>
#   Specifies <xyz>
#.EXAMPLE
#   ScriptFileName.ps1 -Parameter1
#   A sample command that uses the function or script, optionally followed by sample output and a description. Repeat this keyword for each example.
#.LINK
#   https://configurationmanager.uservoice.com/forums/300492-ideas/suggestions/20039980-set-maximum-run-time-on-cumulative-update-for-wind
#.LINK
#   https://configurationmanager.uservoice.com/forums/300492-ideas/suggestions/17224700-change-the-maximum-run-time-of-cumulative-updates
#.NOTES
#   This script is maintained at https://github.com/ChadSimmons/Scripts
#
#   To setup as a ConfigMgr Status Filter Rule run
#      New-CMStatusFilterRule -Name "Set Software Updates Max Execution Time" -AllowDeleteAfterDays 999 -SeverityType Informational -WriteToDatabase $true -ComponentName SMS_WSUS_SYNC_MANAGER -MessageId 6702 -MessageType Milestone -ReportToEventLog $true -RunProgram $true -ProgramPath '"C:\Windows\System32\WindowsPowerShell\v1.0\PowerShell.exe" -ExecutionPolicy Bypass -NoProfile -File "E:Scripts\Scheduled\Set-SCCMSoftwareUpdateMaximumExecutionTime.ps1"'
#
#   Additional information about the function or script.
#   ========== Keywords ==========
#   Keywords: ConfigMgr SCCM Software Updates Patches Maximum Runtime Exceeded
#   ========== Change Log History ==========
#   - 201/12/20 by Chad.Simmons@CatapultSystems.com - Created
#   - 201/12/20 by Chad@ChadsTech.net - Created
#   === To Do / Proposed Changes ===
#   - TODO: Add WhatIf processing
################################################################################

#region    ######################### Parameters and variable initialization ####
[CmdletBinding()]
Param (
	[Parameter(HelpMessage='Set a value that is 15 minutes less than the smallest Maintenance Window')][ValidateRange(20, 700)][int16]$MaximumExecutionMins = 105,
	[Parameter()][ValidateLength(3,3)][string]$SiteCode = 'LAB',
	[Parameter()][ValidateLength(1, 255)][ValidateScript({Test-Connection -ComputerName $_})][string]$SiteServer = $env:ComputerName,
	[Parameter()][string]$LogFile #The default is calculated later in the script to be $ScriptPath\$ScriptBaseName.log
)

    #region    ######################### Debug code
        <#
		If ($psISE) {
			#DEBUG CODE
			[int16]$MaximumExecutionMins = 105
			[string]$SiteCode = "LAB" # Site code
			[string]$SiteServer = "ConfigMgrPrimary.contoso.com" # SMS Provider machine name
			[string]$LogFile #The default is calculated later in the script to be $ScriptPath\$ScriptBaseName.log
		}
        #>
    #endregion ######################### Debug code
#endregion ######################### Parameters and variable initialization ####


#region    ######################### Functions #################################
################################################################################
################################################################################
Function Get-ScriptPath {
	#.Synopsis
	#   Get the folder of the script file
	#.Notes
	#   See snippet Get-ScriptPath.ps1 for excruciating details and alternatives
	#   2017/12/20 by Chad@chadstech.net
    $ScriptFullPath = $(((Get-Variable MyInvocation -Scope 1 -ErrorAction SilentlyContinue).Value).MyCommand.Definition)
    If (Test-Path -Path $ScriptFullPath -ErrorAction SilentlyContinue) {
        $script:ScriptPath = Split-Path -Path $ScriptFullPath -Parent
    } else {
        $ScriptFullPath = $(((Get-Variable HostInvocation -Scope 1 -ErrorAction SilentlyContinue).Value).MyCommand.Definition)
        If (Test-Path -Path $ScriptFullPath -ErrorAction SilentlyContinue) {
            $script:ScriptPath = Split-Path -Path $ScriptFullPath -Parent
        } else {
            If ($psISE) {
                try {
                    $ScriptFullPath = Split-Path $psISE.CurrentFile.FullPath -Parent #this works in psISE and psISE functions
                    If (Test-path -Path $ScriptFullPath -ErrorAction SilentlyContinue) {
                        $script:ScriptPath = $ScriptFullPath
                    } else {
                        Throw 'Aborting! Script Path cannot be determined'
                    }
                } catch {
                    Throw 'Aborting! Script Path cannot be determined`r`n' + $_
                }
            } else {
                Throw 'Aborting! Script Path cannot be determined'
            }
        }
    }
    Write-Verbose "Function Get-ScriptPath: ScriptPath is $($script:ScriptPath)"
}
Function Get-ScriptName {
	#.Synopsis  Get the name of the script file
	#.Notes
	#   See snippet Get-ScriptPath.ps1 for excruciating details and alternatives
	#   2017/07/25 by Chad@chadstech.net
	If ($psISE -and [string]::IsNullOrEmpty($script:ScriptName)) {
		$script:ScriptName = Split-Path $psISE.CurrentFile.FullPath -Leaf #this works in psISE and psISE functions
	} else {
		try {
			$script:ScriptName = ((Get-Variable MyInvocation -Scope 1 -ErrorAction SilentlyContinue).Value).MyCommand.Name
		} catch {
			Throw 'Aborting! Script Name cannot be determined`r`n' + $_
		}
	}
	$script:ScriptBaseName = [System.IO.Path]::GetFileNameWithoutExtension($script:ScriptName)
	Write-Verbose "Function Get-ScriptName: ScriptName is $($script:ScriptName)"
	Write-Verbose "Function Get-ScriptName: ScriptBaseName is $($script:ScriptBaseName)"
	#return $script:ScriptName
}
Function Get-CurrentLineNumber {
    If ($psISE) {
        $script:CurrentLine = $psISE.CurrentFile.Editor.CaretLine
    } else {
        $script:CurrentLine = $MyInvocation.ScriptLineNumber
    }
    return $script:CurrentLine
}
Function Get-CurrentFunctionName {
   (Get-Variable MyInvocation -Scope 1).Value.MyCommand.Name
}
Function Write-LogMessage {
	#.Synopsis Write a log entry in CMtrace format
	#.Notes    2017/05/16 by Chad@chadstech.net - based on Ryan Ephgrave's CMTrace Log Function @ http://www.ephingadmin.com/powershell-cmtrace-log-function
	#.Example  Write-CMEvent -LogFile $LogFile
	#.Example  Write-CMEvent -Message "This is a normal message" -LogFile $LogFile -Console
	#.Example  Write-CMEvent -Message "This is a normal message" -ErrorMessage $Error -LogFile $LogFile -Console
	#.Example  Write-CMEvent -Message "This is a warning" -Type Warn -Component "Test Component" -LogFile $LogFile
	#.Example  Write-CMEvent -Message "This is an Error!" -Type Error -Component "My Component" -LogFile $LogFile
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
		[Parameter(Mandatory = $true)]$Message,
		[ValidateSet('Error','Warn','Warning','Info','Information','1','2','3')][string]$Type,
		$Component = $script:ScriptName, #$($MyInvocation.MyCommand.Name), #Default to ScriptName
        $LogFile = $script:LogFile, #"$env:WinDir\Logs\Scripts\$([IO.Path]::ChangeExtension($(Split-Path $(If ($PSCommandPath) { $PSCommandPath } else { $psISE.CurrentFile.FullPath }) -Leaf),'.log'))",
		[switch]$Console
	)
	Switch ($Type) {
		{ @('3', 'Error') -contains $_ } { $intType = 3 } #3 = Error (red)
		{ @('2', 'Warn', 'Warning') -contains $_ } { $intType = 2 } #2 = Warning (yellow)
        Default { $intType = 1 } #1 = Normal
	}
	If ($Component -eq $null) {$Component = ' '} #Must not be null
	try { #write log file message
		"<![LOG[$Message]LOG]!><time=`"$(Get-Date -Format "HH:mm:ss.ffffff")`" date=`"$(Get-Date -Format "MM-dd-yyyy")`" component=`"$Component`" context=`"`" type=`"$Type`" thread=`"`" file=`"`">" | Out-File -Append -Encoding UTF8 -FilePath $LogFile
	} catch { Write-Error "Failed to write to the log file '$LogFile'" }
	If ($Console) { Write-Output $Message } #write to console if enabled
}; Set-Alias -Name 'Write-CMEvent' -Value 'Write-LogMessage' -Description 'Log a message in CMTrace format'
Function Start-Script ($LogFile) {
	$script:ScriptStartTime = Get-Date
	$Progress.Activity = "$ScriptName..."; Write-Progress @Progress
	#if the LogFile is undefined set to <ScriptPath>\<ScriptName>.log
	If ([string]::IsNullOrEmpty($LogFile)) {
		$script:LogFile = "$script:ScriptPath\$([System.IO.Path]::GetFileNameWithoutExtension($script:ScriptName)).log"
	} else {
		$script:LogFile = $LogFile
	}
	#if the LogFile folder does not exist, create the folder
	Set-Variable -Name LogPath -Value $(Split-Path -Path $script:LogFile -Parent) -Description 'The folder/directory containing the log file' -Scope Script
	If (!(Test-Path $LogPath)) { New-Item -Path $LogPath -ItemType Directory -Force}
	#write initial message
	Write-LogMessage -Message "==================== SCRIPT START ====================" -Component $script:ScriptName
	Write-Output "Logging to $script:LogFile"
}
Function Stop-Script ($ReturnCode) {
	Write-LogMessage -Message "Exiting with return code $ReturnCode"
	$ScriptEndTime = Get-Date
	$ScriptTimeSpan = New-TimeSpan -Start $script:ScriptStartTime -end $ScriptEndTime #New-TimeSpan -seconds $(($(Get-Date)-$StartTime).TotalSeconds)
	Write-LogMessage -Message "Script Completed in $([math]::Round($ScriptTimeSpan.TotalSeconds)) seconds, started at $(Get-Date $script:ScriptStartTime -Format 'yyyy/MM/dd hh:mm:ss'), and ended at $(Get-Date $ScriptEndTime -Format 'yyyy/MM/dd hh:mm:ss')" -Console
	Write-LogMessage -Message "==================== SCRIPT COMPLETE ====================" -Component $script:ScriptName
	Write-Progress @Progress -Complete
	Exit $ReturnCode
}

Function Connect-ConfigMgr {
	Param (
		[Parameter(Mandatory=$false)][ValidateLength(3,3)][string]$SiteCode,
		[Parameter(Mandatory=$false)][ValidateLength(1, 255)][string]$SiteServer
	)
    #.Synopsis
    #   Load Configuration Manager PowerShell Module
    #.Description
    #   if SiteCode is not specified, detect it
    #   if SiteServer is not specified, use the computer from PSDrive if it exists, otherwise use the current computer
    #.Link
    #   http://blogs.technet.com/b/configmgrdogs/archive/2015/01/05/powershell-ise-add-on-to-connect-to-configmgr-connect-configmgr.aspx
    If ($Env:SMS_ADMIN_UI_PATH -ne $null) {
        #import the module if it exists
        If ((Get-Module ConfigurationManager) -eq $null) {
            Write-Verbose 'Importing ConfigMgr PowerShell Module...'
            $TempVerbosePreference = $VerbosePreference
            $VerbosePreference = 'SilentlyContinue'
            try {
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
                $SiteCode  = (Get-PSDrive -PSProvider -ErrorAction Stop CMSITE).Name
            } catch {
                Throw $_
            }
        }
        # Connect to the site's drive if it is not already present
        if ((Get-PSDrive -Name $SiteCode -PSProvider CMSite -ErrorAction SilentlyContinue) -eq $null) {
            Write-Verbose -Message "Creating ConfigMgr Site Drive $($CMSiteCode):\ on server $SiteServer"
            # If SiteCode was not specified use the current computer
            If ([string]::IsNullOrEmpty($SiteServer)) {
                $SiteServer = $env:ComputerName
            }
            try {
                New-PSDrive -Name $SiteCode -PSProvider CMSite -Root $SiteServer
            } catch {
                Throw $_
            }
        }
        #change location to the ConfigMgr Site
        try {
            Push-Location "$($SiteCode):\"
        } catch {
            Write-Error "Error connecting to the ConfigMgr site"
            Throw $_
        }
    } else {
        Throw "The ConfigMgr PowerShell Module does not exist!  Install the ConfigMgr Admin Console first."
    }
}
################################################################################
################################################################################
#endregion ######################### Functions #################################

#region    ######################### Initialization ############################
$Progress = @{Activity = "PowerShell script..."; Status = "Initializing..."} ; Write-Progress @Progress
#$script:Console = $true
#$script:EventLog = $true
Get-ScriptPath
Get-ScriptName
Start-Script #-LogFile "$env:WinDir\Logs\$([System.IO.Path]::GetFileNameWithoutExtension($(Get-ScriptName))).log"

#endregion ######################### Initialization ############################
#region    ######################### Main Script ###############################

Connect-ToConfigMgr -SiteCode $SiteCode -SiteServer $SiteServer

#Get the list of updates to change
$Progress.Status = 'Getting Software Updates' ; Write-Progress @Progress
try {
	$Updates = Get-CMSoftwareUpdate -Fast -CategoryName @('Windows 10','Windows Server 2016') -IsExpired $false -IsSuperseded $false | Where MaxExecutionTime -LT $($MaximumExecutionMins*60)
} catch {
	Write-LogMessage -Message 'Failed to get the list of Software Updates' -Type Error
	Stop-Script -ReturnCode 2
	exit 2
}

#Exclude Windows Feature Updates
#$Updates = $Updates | Where LocalizedDisplayName -NotLike 'Feature update to Windows*'

Write-LogMessage -Message "Found $($Updates.Count) Updates with Maximum Execution Time less than $MaximumExecutionMins minutes."
Write-Verbose -Message $($Updates | Select -First 1 | Format-List | Out-String)
Write-Verbose -Message $($Updates | Select MaxExecutionTime, LocalizedDisplayName | Format-Table -AutoSize | Out-String)

#Set the Max Execution Time on the list of updates
$Progress.Status = 'Updating Software Updates' ; Write-Progress @Progress
ForEach ($Update in $Updates) {
	try {
		$Update | Set-CMSoftwareUpdate -MaximumExecutionMins $MaximumExecutionMins
		Write-LogMessage -Message "Set Maximum Execution Time for Software Update [$($Update.LocalizedDisplayName)] with CI_ID [$($Update.CI_ID)] to $MaximumExecutionMins minutes.  Previous value was $($Update.MaxExecutionTime) seconds."
	} catch {
		Write-LogMessage -Message "Failed setting Maximum Execution Time for Software Update [$($Update.LocalizedDisplayName)] with CI_ID []." -Type Warning
	}
}

Pop-Location

#endregion ######################### Main Script ###############################
#region    ######################### Deallocation ##############################
Write-Output "LogFile = $LogFile"
Stop-Script -ReturnCode 0
#endregion ######################### Deallocation ##############################