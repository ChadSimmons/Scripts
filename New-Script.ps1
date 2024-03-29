#requires -Version 3.0
##requires -RunAsAdministrator
################################################################################################# #BOOKMARK: Script Help
#   Template updated 2024/01/22
#.SYNOPSIS
#   ScriptFileName.ps1
#   A brief description of the function or script
#.DESCRIPTION
#   A detailed description of the function or script
#	About Comment Based Help https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_comment_based_help
#
#   THIS CODE AND ANY RELATED INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED OR IMPLIED,
#   INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR PURPOSE.  We
#   grant You a nonexclusive, royalty-free right to use and modify, but not distribute, the code, provided that You agree:
#   (i) to retain Our name, logo, or trademarks referencing Us as the original provider of the code;
#   (ii) to indemnify, hold harmless, and defend Us and Our suppliers from and against any claims or lawsuits, including
#   attorney fees, that arise or result from the use of the Code.
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
	[Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, HelpMessage = 'This is the first parameter.')][string[]]$Parameter1,
	[Parameter(Mandatory = $false, HelpMessage = '~myDescription~')][switch]$MySwitch,
	[Parameter(Mandatory = $false, HelpMessage = 'Full folder directory path and file name for logging')][Alias('Log')][string]$LogFile # Functions default this to CommonDocuments\Logs\... = $(Join-Path -Path $([System.Environment]::GetFolderPath('Personal')) -ChildPath 'Logs\Scripts.log')
)
<#region ############# Debug code ######################
	$Parameter1="this is a string"
	If (-not($PSBoundParameters.ContainsKey('Parameter1'))) { [string]$Parameter1 = "ABC"; $PSBoundParameters.Add('Parameter1', $Parameter1) }
#endregion ########## Debug code #####################>
#endregion ########## Parameters and variable initialization ##########################################################>

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
	$script:ScriptStartTime = Get-Date
	$script:ScriptFile = $ScriptFile
	$script:ScriptPath = Split-Path -Path $script:ScriptFile -Parent
	$script:ScriptFileName = Split-Path -Path $script:ScriptFile -Leaf
	If ([string]::IsNullOrEmpty($script:LogFile)) { $script:LogFile = $(Join-Path -Path $([system.environment]::GetFolderPath('CommonApplicationData')) -ChildPath "Logs\$([System.IO.Path]::ChangeExtension($script:ScriptFileName, 'log'))") }
	If (-not(Test-Path -Path $(Split-Path -Path $script:LogFile -Parent) -PathType Container -ErrorAction SilentlyContinue)) {
		New-Item -ItemType Directory -Path $(Split-Path -Path $script:LogFile -Parent) -Force | Out-Null
	}
	If ([string]::IsNullOrEmpty($global:TZOffset)) { $global:TZOffset = [System.TimeZoneInfo]::Local.BaseUtcOffset.TotalMinutes }
	Write-LogMessage -Message "==================== Starting Script ====================" -Console
	Write-LogMessage -Message "Script Info...`n   Script file [$script:ScriptFile]`n   Log file [$LogFile]`n   Computer [$env:ComputerName]`n   Start time [$(Get-Date -Format 'F')]" -Console
}
Function Write-LogMessage ($Message, [ValidateSet('Error', 'Warn', 'Warning', 'Info', 'Information', '1', '2', '3')]$Type = '1', $LogFile = $script:LogFile, [switch]$Console) {
	#.Synopsis Write a log entry in CMTrace format with almost as little code as possible (i.e. Simplified Edition)
	#If ([string]::IsNullOrEmpty($global:TZOffset)) { $global:TZOffset = [System.TimeZoneInfo]::Local.BaseUtcOffset.TotalMinutes }
	#If (-not(Test-Path 'variable:script:LogFile')) { $script:LogFile = $LogFile }
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

Write-Host 'Hello World in color' -ForegroundColor 'White' -BackgroundColor 'DarkRed' -NoNewline
Write-Output "`$WhatIfPreference is [$WhatIfPreference]"
Write-Verbose "`$VerbosePreference is [$VerbosePreference]" -Verbose #use -Verbose switch on Write-Verbose in place of Write-Output or Write-Host
Write-Debug "`$DebugPreference is [$DebugPreference]" -Debug

#endregion ########## Main Script ######################################################################################
#region ############# Finalization ########################################################## #BOOKMARK: Script Finalize
If ($WhatIfPreference) { Write-LogMessage -Message '     ========== Running with WhatIf.  NO ACTUAL CHANGES are expected to be made! ==========' -Type Warn }
Write-LogMessage -Message "==================== Completed script [$script:ScriptFile] in $('{0:g}' -f $(New-TimeSpan -Start $ScriptStartTime -End $(Get-Date))) at $(Get-Date -Format 'F') ====================" -Console
#endregion ########## Finalization ####################################################################################>