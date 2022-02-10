################################################################################
#.SYNOPSIS
#   Write-TSVariables.ps1
#   Write Task Sequence variables to TXT/CSV/LOG files, excluding sensitive variables (accounts and passwords)
#      and generally unimportant data (hashes) that makes the export difficult to read.
#.DESCRIPTION
#    Usage:  Run in SCCM Task Sequence to export TS-Variables to disk ("_SMSTSLogPath").
#            Variables known to contain sensitive information will be excluded.
#    Config: List of variables to exclude, edit as needed:
#            $VariablesExcluded = @('_OSDOAF','_SMSTSReserved','_SMSTSTaskSequence')
#.EXAMPLE
#   powershell.exe -ExecutionPolicy Bypass -File Write-TSVariables.ps1
#.EXAMPLE
#   Write-TSVariables.ps1 -OutputToCSV $false -OutputToLog $true -CSVDelimiter ',' -LogPath 'C:\Windows\Temp'
#.LINK
#   https://gallery.technet.microsoft.com/Task-Sequence-Variables-de05b064
#   http://ccmexec.com/2017/03/copy-and-zip-osd-log-files-in-a-task-sequence-using-powershell/
#.NOTES
#   This script is maintained at https://github.com/ChadSimmons/Scripts
#   Additional information about the function or script.
#   ========== Keywords ==========
#   Keywords: export output log task sequence variables
#   ========== Change Log History ==========
#   - 2022/01/31 by Chad.Simmons@CatapultSystems.com - bug fixes
#   - 2018/03/07 by Chad.Simmons@CatapultSystems.com - Added logging for CMTrace, and CSV
#                   Added wildcard exclusions
#                   Added process environment variables
#   - 2016/11/24 by Johan Schrewelius, Onevinn AB - Created as TSVarsSafeDump.ps1
#   === To Do / Proposed Changes ===
################################################################################
[CmdletBinding()] #(SupportsShouldProcess=$false, ConfirmImpact="Low")
Param (
	[parameter()][bool]$OutputToLog = $true,
	[parameter()][bool]$OutputToCSV = $true,
	[parameter()][string]$CSVDelimiter = ',', #"`t",
	[parameter()][string]$LogPath
)

#A list of variables which are completely ignored
$VariablesExcluded = @('_OSDOAF', '*password*', '_SMSTSReserved*')
#A list of variables which will have the value suppressed (the variable name will still be logged)
If ($VerbosePreference -eq 'Continue') {
    $VariablesSuppressed = @()
} Else {
    $VariablesSuppressed = @('*Policy', '_TSSub-*', '_SMSTS*Config', '_SMSTSPkgHash*', '_SMSTSMediaAppDocs', '_SMSTSMediaAppMetaData', 'ClientTokenSignature', '_SMSTS*Token', '_SMSTS*Certs', '_SMSTSMediaPFX', '_SMSTS*Certificate', '_SMSTSAuthenticator', '_SMSTS*Policy', '_SMSTSPolicy*', '_SMSTSTaskSequence')
}
#region    ######################### Parameters and variable initialization ####

#region    ######################### Functions #################################
################################################################################
################################################################################
Function Write-LogMessageSE {
	#.Synopsis Write a log entry in CMTrace format with as little code as possible (i.e. Simplified Edition)
	param ($Message, [ValidateSet('Error','Warn','Warning','Info','Information','1','2','3')]$Type='1', $LogFile=$global:LogFile)
	If (!(Test-Path 'variable:global:LogFile')){$global:LogFile=$LogFile}
	Switch($Type){ {@('2','Warn','Warning') -contains $_}{$Type=2}; {@('3','Error') -contains $_}{$Type=3}; Default{$Type=1} }
	try { Add-Content -Path $LogFile -Encoding UTF8 -WhatIf:$false -Confirm:$false -Value "<![LOG[$Message]LOG]!><time=`"$(Get-Date -F HH:mm:ss.fff)+000`" date=`"$(Get-Date -F 'MM-dd-yyyy')`" component=`" `" context=`" `" type=`"$Type`" thread=`"$PID`" file=`"`">" -ErrorAction Stop
	} catch { Write-Warning -Message "Unable to append log [$LogFile] with message [$Message]" }
} Set-Alias -Name Write-LogMessage -Value Write-LogMessageSE
################################################################################
################################################################################
#endregion ######################### Functions #################################


#region    ######################### Initialization ############################
#connect to ConfigMgr Task Sequence Environment
try {
    $TSenv = New-Object -COMObject Microsoft.SMS.TSEnvironment
} catch {
    Throw $_
    Exit 10 #(0xA) ERROR_BAD_ENVIRONMENT / The environment is incorrect.
}

#build the log file path and base name.  File extension will be added later
If ([string]::IsNullOrEmpty($LogPath)) { $LogPath = $TSenv.Value("_SMSTSLogPath") }
$LogFileBaseName = Join-Path -Path $LogPath -ChildPath "TSVariables-$(Get-Date -Format "yyyyMMdd_HHmmss")"

#Create a hash table of variable names and values
$myVariables = [ordered]@{}
#endregion ######################### Initialization ############################
#region    ######################### Main Script ###############################

#region Get Task Sequence Variables, removing exclusions, and suppressing long and uninteresting values (if not verbose)
ForEach ($TSVariable in $TSenv.GetVariables()) {
    $TSValue = $TSenv[$TSVariable] #$TSenv.value("$TSVariable")
    ForEach ($VariableExcluded in $VariablesExcluded) {
        If ($TSVariable -like $VariableExcluded) {
            $TSValue = '~Excluded~'
            Break
        }
    }
    ForEach ($VariableSuppressed in $VariablesSuppressed) {
        If ($TSVariable -like $VariableSuppressed) {
            $TSValue = '<Value suppressed for readability>'
            Break
        }
    }
    If ($TSValue -ne '~Excluded~') {
		$myVariables.Add($TSVariable, $TSValue)
	}
}
Remove-Variable -Name TSVariable, TSValue, VariablesExcluded, VariableExcluded, VariablesSuppressed, VariableSuppressed -ErrorAction SilentlyContinue
#endregion Get Task Sequence Variables

#region Get Process Environment Variables
ForEach ($ENVVariable in $(Get-ChildItem env:)) {
	$myVariables.Add("ENV_$($ENVVariable.Name)", $ENVVariable.Value)
}
Remove-Variable -Name ENVVariable -ErrorAction SilentlyContinue
#endregion Get Process Environment Variables

#region Get PowerShell Variables
ForEach ($PSVariable in $(Get-ChildItem variable: | Where-Object { $_.Name -notin @('null', 'error','output','input','StackTrace') })) {
    $myVariables.Add("PS_$($PSVariable.Name)", $PSVariable.Value)
}
#endregion Get PowerShell Variables

#region Write variables to file(s)
ForEach ($Variable in $myVariables.GetEnumerator()) {
    If ($OutputToCSV) { [PSCustomObject]@{Name = $Variable.Name; Value = $Variable.Value } | Export-Csv -Path "$($LogFileBaseName).csv" -NoTypeInformation -Delimiter $CSVDelimiter -Append }
    If ($OutputToLog) { Write-LogMessage -Message "$($Variable.Name) = $($Variable.Value)" -LogFile "$($LogFileBaseName).log" }
}
#endregion Write variables to file(s)