################################################################################################# #BOOKMARK: Script Help
#.SYNOPSIS
#   Reset-MCMClientPolicy.ps1
#   Purge existing ConfigMgr client policy (hard reset) and force a full (not delta) policy retrieval
#.PARAMETER ComputerName
#   Specifies a computer name, comma separated list of computer names, or file with one computer name per line
#.PARAMETER Action
#   Purge (default) or FullPolicy
#   Specifies if the policy should be purged before requesting a full policy retrieval instead of a delta policy
#.PARAMETER GetCred
#   Switch to prompt for credentials to use with the remote WMI connections
#.PARAMETER Quiet
#   Switch to suppress output
#.PARAMETER LogFile
#   Path and file name of CMTrace style log file to record activity.  Default is to the path and name of the script with .log extension
#.EXAMPLE
#   ScriptFileName.ps1 -ComputerName $env:ComputerName
#.EXAMPLE
#   ScriptFileName.ps1 -Quiet -Action FullPolicy -ComputerName $env:ComputerName,Computer2,Computer3
#.NOTES
#	based on https://techibee.com/powershell/reset-and-purge-existing-policies-in-sccm-using-powershell/2093
#
#	https://docs.microsoft.com/en-us/mem/configmgr/develop/reference/core/clients/client-classes/resetpolicy-method-in-class-sms_client
#	Flags identifying the policy. Possible values are:
#	PARAMETERS
#	Value	Description
#	0	The next policy request will be for a full policy instead of the change in policy since the last policy request.
#	1	The existing policy will be purged completely.
#
#   === simplified version ===
#	$Computers = Get-Content -Path "C:\Temp\PolicyRefresh.txt";
#   $Cred = Get-Credential
#	ForEach ($Computer in $Computers) { Write-Host "Resetting ConfigMgr client policy on $Computer"; Invoke-WmiMethod -Namespace root\CCM -Class SMS_Client -Name ResetPolicy -ArgumentList '1' -ComputerName $Computer -Credential $Cred -ErrorAction Stop }
#
#   This script is maintained at https://github.com/ChadSimmons/Scripts
#   Additional information about the function or script.
#   ========== Keywords ==========
#   Keywords: Microsoft Endpoint Configuration Manager, MECM, MEMCM, SCCM, ConfigMgr, policy
#   ========== Change Log History ==========
#   - 2021/03/16 by Chad.Simmons@CatapultSystems.com - Created
#   - 2021/03/16 by Chad@ChadsTech.net - Created
#   === To Do / Proposed Changes ===
#   #TODO: Add additional error handling
########################################################################################################################
#region ############# Parameters and variable initialization ############################## #BOOKMARK: Script Parameters
[cmdletbinding()]
param(
	[parameter()][string[]]$ComputerName = $env:ComputerName, #a computer name, comma separated list of computer names, or file with one computer name per line
	[parameter()][ValidateSet('Purge', 'FullPolicy')][string]$Action = 'Purge',
	[parameter()][switch]$GetCred,
	[parameter()][switch]$Quiet, #don't display output,
	[parameter()][string]$LogFile
)
	#region ############# Debug code ######################
	#endregion ########## Debug code ######################
#endregion ########## Parameters and variable initialization ###########################################################

#region ############# Functions ############################################################ #BOOKMARK: Script Functions
########################################################################################################################
########################################################################################################################
Function Start-Script ([parameter(Mandatory = $true)][string]$ScriptFile) {
	#.Synopsis Gather information about the script and write the log header information
	$script:ScriptStartTime = Get-Date
	$script:ScriptFile = $ScriptFile
	$script:ScriptPath = Split-Path -Path $script:ScriptFile -Parent
	$script:ScriptFileName = Split-Path -Path $script:ScriptFile -Leaf
	If ([string]::IsNullOrEmpty($script:LogFile)) { $script:LogFile = $(Join-Path -Path $([system.environment]::GetFolderPath('CommonApplicationData')) -ChildPath "Logs\$([System.IO.Path]::ChangeExtension($script:ScriptFileName, 'log'))") }
	If (-not(Test-Path -Path $(Split-Path -Path $script:LogFile -Parent) -PathType Container -ErrorAction SilentlyContinue)) {
		New-Item -ItemType Directory -Path $(Split-Path -Path $script:LogFile -Parent) -Force | Out-Null
	}
	If ([string]::IsNullOrEmpty($global:TZOffset)) { $global:TZOffset = [System.TimeZoneInfo]::Local.BaseUtcOffset.TotalMinutes }
	Write-LogMessage -Message '==================== Starting Script ====================' -Console
	Write-LogMessage -Message "Script Info...`n   Script file [$script:ScriptFile]`n   Log file [$LogFile]`n   Computer [$env:ComputerName]`n   Start time [$(Get-Date -Format 'F')]" -Console
}
Function Write-LogMessage ($Message, [ValidateSet('Error', 'Warn', 'Warning', 'Info', 'Information', '1', '2', '3')]$Type = '1', $LogFile = $script:LogFile, [switch]$Console) {
	#.Synopsis Write a log entry in CMTrace format with almost as little code as possible (i.e. Simplified Edition)
	Switch ($Type) { { @('2', 'Warn', 'Warning') -contains $_ } { $Type = 2 }; { @('3', 'Error') -contains $_ } { $Type = 3 }; Default { $Type = 1 } }
	If ($Console) { Write-Output "$(Get-Date -F 'yyyy-MM-dd HH:mm:ss.fff')$TZOffset`t$(Switch ($Type) { 2 { 'WARNING: '}; 3 { 'ERROR: '}})$Message" }
	try {
		Add-Content -Path "filesystem::$LogFile" -Encoding UTF8 -WhatIf:$false -Confirm:$false -Value "<![LOG[$Message]LOG]!><time=`"$(Get-Date -F 'HH:mm:ss.fff')$TZOffset`" date=`"$(Get-Date -F 'MM-dd-yyyy')`" component=`"$ScriptName`" context=`" `" type=`"$Type`" thread=`"$PID`" file=`"`">" -Force -ErrorAction Continue
	} catch { Write-Warning -Message "Failed writing to log [$LogFile] with message [$Message]" }
} # Write-LogMessage function v2024.01.22.1810

########################################################################################################################
########################################################################################################################
#endregion ########## Functions ########################################################################################


#region ############# Initialize ########################################################## #BOOKMARK: Script Initialize
Start-Script -ScriptFile $(If ($PSise) { $PSise.CurrentFile.FullPath } Else { $MyInvocation.MyCommand.Definition })
#endregion ########## Initialization ###################################################################################

#region ############# Main Script ############################################################### #BOOKMARK: Script Main

Write-LogMessage -Message "params (-ComputerName [$ComputerName] -Action [$Action] -GetCred [$GetCred] -Quiet [$Quiet])"


#if ComputerName is a file, read the file content
If (Test-Path -Path $($ComputerName | Select-Object -First 1) -PathType Leaf -ErrorAction Stop) {
	Write-LogMessage -Message "Reading file [$ComputerName] for list of computer names"
	[string[]]$Computername = Get-Content -Path $ComputerName
}

If ($GetCred) {
	Write-LogMessage -Message "Getting credentials for remote WMI connections"
	$Cred = Get-Credential
}

Switch ($Action) {
	'FullPolicy' { $Gflag = 0 }
	Default { $Gflag = 1 }
}
Write-LogMessage -Message "Gflag set to $Gflag based on Action $Action"


$global:ScriptStatus = @()
$TotalCount = $ComputerName.Count; $iCount = 0
Write-LogMessage -Message "$TotalCount computers to be processed"
ForEach($Computer in $ComputerName) {
	$iCount++; Write-Progress -Activity "[$iCount of $TotalCount] Resetting ConfigMgr Client local policy" -Status $Computer
	$ComputerStatus = [PSCustomObject][ordered]@{ ComputerName = $Computer; Status = $null; Timestamp = Get-Date }
	try {
		If ($Cred) {
			$Client = Get-WmiObject -Class SMS_Client -Namespace root\ccm -List -ComputerName $Computer -ErrorAction Stop -Credential $Cred
		} Else {
			$Client = Get-WmiObject -Class SMS_Client -Namespace root\ccm -List -ComputerName $Computer -ErrorAction Stop
		}
	} catch {
		$ComputerStatus.Status = "WMI connection failed"
		Write-LogMessage -Message "[$Computer] $($ComputerStatus.Status)" -Type Warn -Verbose
	}
	If ($Client) {
		try {
			$ReturnVal = $Client.ResetPolicy($Gflag)
			$ComputerStatus.Status = 'ResetPolicy Success'
			Write-LogMessage -Message "[$Computer] $($ComputerStatus.Status)"
		} catch {
			$ComputerStatus.Status = "ResetPolicy Failed ($ReturnVal)"
			Write-LogMessage -Message "[$Computer] $($ComputerStatus.Status)" -Type Warn -Verbose
		}
	}
	$ScriptStatus += $ComputerStatus
	Remove-Variable -Name Client, ReturnVal, ComputerStatus
}
#endregion ########## Main Script ######################################################################################

#region ############# Finalization ########################################################## #BOOKMARK: Script Finalize
If (-not($Quiet)) {
	$ScriptStatus
	Write-Host "Output saved in global variable ScriptStatus"
}
Write-LogMessage -Message "==================== Completed script [$script:ScriptFile] at $(Get-Date -Format 'F') ====================" -Console
#endregion ########## Finalization #####################################################################################