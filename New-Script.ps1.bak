#requires -Version 3.0
#requires -RunAsAdministrator
################################################################################################# #BOOKMARK: Script Help
# THIS CODE AND ANY RELATED INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED OR IMPLIED,
# INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR PURPOSE.  We
# grant You a nonexclusive, royalty-free right to use and modify, but not distribute, the code, provided that You agree:
# (i) to retain Our name, logo, or trademarks referencing Us as the original provider of the code;
# (ii) to indemnify, hold harmless, and defend Us and Our suppliers from and against any claims or lawsuits, including
# attorney fees, that arise or result from the use of the Code.
#
#.SYNOPSIS
#   ScriptFileName.ps1
#   A brief description of the function or script
#.DESCRIPTION
#   A detailed description of the function or script
#	About Comment Based Help https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_comment_based_help
#.PARAMETER <name>
#   Specifies <xyz>
#.Parameter LogFile
#   Full folder directory path and file name for logging
#   Defaults to C:\Windows\Logs\<ScriptFileName>.log
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
#   This script is maintained at ???????????????????????????????????????????????????????????????????????????????????????
#   Additional information about the function or script.
#   ========== Keywords =========================
#   Keywords: ???
#   ========== Change Log History ===============
#   - YYYY/MM/DD by name@contoso.com - ~updated description~
#   - YYYY/MM/DD by name@contoso.com - created
#   ========== To Do / Proposed Changes =========
#   - #TODO: None
#   ===== Additional References and Reading =====
#   - <link title>: https://domain.url
########################################################################################################################
#region ############# Parameters and variable initialization ############################## #BOOKMARK: Script Parameters
[CmdletBinding()] #(SupportsShouldProcess=$false, ConfirmImpact="Low")
Param (
	[Parameter(Mandatory = $false, HelpMessage = '~myDescription~')][switch]$MySwitch,
	[Parameter(Mandatory = $false, HelpMessage = 'Full folder directory path and file name for logging')][Alias('Log')][string]$LogFile
)
#endregion ########## Parameters and variable initialization ###########################################################

#region ############# Functions ############################################################ #BOOKMARK: Script Functions
########################################################################################################################
########################################################################################################################
Function Get-FunctionExample ($Parameter1) {
	<#
	.Synopsis
	   Get...
	.Description
	   Set...
	.Notes
	   - YYYY/MM/DD by name@contoso.com - ~updated description~
	   - YYYY/MM/DD by name@contoso.com - created
	.Example
	   Get-FunctionExample -Parameter1 'abc'
	#>
}
Function Start-Script ([parameter(Mandatory = $true)][string]$ScriptFile) {
	#.Synopsis Gather information about the script and write the log header information
	$script:ScriptFile = $ScriptFile
	$script:ScriptPath = Split-Path -Path $script:ScriptFile -Parent
	$script:ScriptFileName = Split-Path -Path $script:ScriptFile -Leaf
	If ([string]::IsNullOrEmpty($script:LogFile)) { $script:LogFile = [System.IO.Path]::ChangeExtension($ScriptFile, 'log') }
	Write-LogMessage -Message "==================== Starting Script ===================="
	Write-LogMessage -Message "Script Info...`n   Script file [$script:ScriptFile]`n   Log file [$LogFile]`n   Computer [$env:ComputerName]`n   Start time [$(Get-Date -Format 'F')]" -Console
}
Function Write-LogMessage {
	#.Synopsis Write a log entry in CMTrace format with almost as little code as possible (i.e. Simplified Edition)
	param ($Message, [ValidateSet('Error', 'Warn', 'Warning', 'Info', 'Information', '1', '2', '3')]$Type = '1', $LogFile = $script:LogFile, [switch]$Console)
	If ([string]::IsNullOrEmpty($LogFile)) { $LogFile = "$env:SystemRoot\Logs\ScriptCMTrace.log" }
	If (-not(Test-Path 'variable:script:LogFile')) { $script:LogFile = $LogFile }
	Switch ($Type) { { @('2', 'Warn', 'Warning') -contains $_ } { $Type = 2 }; { @('3', 'Error') -contains $_ } { $Type = 3 }; Default { $Type = 1 } }
	If ($Console) { Write-Output "$(Get-Date -F 'yyyy/MM/dd HH:mm:ss.fff')`t$(Switch ($Type) { 2 { 'WARNING: '}; 3 { 'ERROR: '}})$Message" }
	try {
		Add-Content -Path "filesystem::$LogFile" -Encoding UTF8 -WhatIf:$false -Confirm:$false -Value "<![LOG[$Message]LOG]!><time=`"$(Get-Date -F HH:mm:ss.fff)+000`" date=`"$(Get-Date -F 'MM-dd-yyyy')`" component=`" `" context=`" `" type=`"$Type`" thread=`"$PID`" file=`"`">" -ErrorAction Stop
	} catch { Write-Warning -Message "Failed writing to log [$LogFile] with message [$Message]" }
}
########################################################################################################################
########################################################################################################################
#endregion ########## Functions ########################################################################################

#region ############# Initialize ########################################################## #BOOKMARK: Script Initialize
Start-Script -ScriptFile $(If ($PSise) { $PSise.CurrentFile.FullPath } Else { $MyInvocation.MyCommand.Definition })
#endregion ########## Initialization ###################################################################################
#region ############# Main Script ############################################################### #BOOKMARK: Script Main

Write-Host 'Hello World in color' -ForegroundColor 'White' -BackgroundColor 'DarkRed' -NoNewline
Write-Output "`$WhatIfPreference is [$WhatIfPreference]"
Write-Verbose "`$VerbosePreference is [$VerbosePreference]" -Verbose #use -Verbose switch on Write-Verbose in place of Write-Output or Write-Host
Write-Debug "`$DebugPreference is [$DebugPreference]" -Debug

#endregion ########## Main Script ######################################################################################
#region ############# Finalization ########################################################## #BOOKMARK: Script Finalize
Write-LogMessage -Message "==================== Completed Script ====================" -Console
#endregion ########## Finalization #####################################################################################