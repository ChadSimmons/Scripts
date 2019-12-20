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
#   Write-TSVariables.ps1 -OutputToCSV -OutputToLog -OutputToLogComponentized -CSVDelimiter ',' -LogPath 'C:\Windows\Temp'
#.LINK
#   https://gallery.technet.microsoft.com/Task-Sequence-Variables-de05b064
#   http://ccmexec.com/2017/03/copy-and-zip-osd-log-files-in-a-task-sequence-using-powershell/
#.NOTES
#   This script is maintained at https://github.com/ChadSimmons/Scripts
#   Additional information about the function or script.
#   ========== Keywords ==========
#   Keywords:
#   ========== Change Log History ==========
#   - 2018/03/07 by Chad.Simmons@CatapultSystems.com - Added logging for CMTrace, TXT, and CSV.
#                   Added wildcard exclusions
#                   Added process environment variables
#   - 2016/11/24 by Johan Schrewelius, Onevinn AB - Created as TSVarsSafeDump.ps1
#   === To Do / Proposed Changes ===
#   - TODO: Mirror functionality from Write-TSVariables.wsf
#   - TODO: add parameters
#   - TODO: add output header and footer? (script name, date/time, etc.)
#   - TODO: use regex for variable name matching for better performance
#   - TODO:
#   - TODO:
################################################################################
[CmdletBinding()] #(SupportsShouldProcess=$false, ConfirmImpact="Low")
Param (
	[parameter()]$SuppressNoise = $true,
	[parameter()]$OutputToLog = $true,
	[parameter()]$OutputToLogComponentized,
	[parameter()]$OutputToCSV,
	[parameter()]$CSVDelimiter = ',', #"`t",
	[parameter()]$LogPath
)
	#A list of variables which are completely ignored
$VariablesExcluded = @('_OSDOAF', '*password*', '_SMSTSReserved', '_SMSTSTaskSequence')
#A list of variables which will have the value suppressed (the variable name will still be logged)
If ($SuppressNoise -eq $true) {
	$VariablesSuppressed = @('*Policy', '_SMSTS*Config', '_SMSTSPkgHash*', '_SMSTSMediaAppDocs', '_SMSTSMediaAppMetaData', 'ClientTokenSignature', '_SMSTSMPCerts', '_SMSTSMediaPFX', '_SMSTSSiteSigningCertificate', '_SMSTSAuthenticator')
} Else {
	$VariablesSuppressed = @()
}
$OutputToCSV = $true
$CSVDelimiter = ',' #"`t"
$OutputToLog = $true
$OutputToLogComponentized = $true
#region    ######################### Parameters and variable initialization ####

#region    ######################### Functions #################################
################################################################################
################################################################################
Function Write-LogMessage {
	FIXME: !!!!!!!!!!!!!!!!!!!!!!!!!   Import from Function_Write-LogMessage.ps1 !!!!!!!!!!!!!!!!!!
}
################################################################################
################################################################################
#endregion ######################### Functions #################################


#region    ######################### Initialization ############################
try {
    $TSenv = New-Object -COMObject Microsoft.SMS.TSEnvironment
} catch {
    Throw $_
    Exit 10 #(0xA) ERROR_BAD_ENVIRONMENT / The environment is incorrect.
}
#build the log file path and base name.  File extension will be added later
#FIXME: If ($LogPath parameter not passed ) { $LogPath = $TSenv.Value("_SMSTSLogPath") }
$LogFileBaseName = Join-Path -Path $LogPath -ChildPath "TSVariables-$(Get-Date -Format "yyyyMMdd_HHmmss")"
#Create a hash table of variable names and values
$myVariables = @{}
#endregion ######################### Initialization ############################
#region    ######################### Main Script ###############################

#region ????
function MatchArrayItem {
    param (
        [array]$Arr,
        [string]$Item
    )
    $result = ($null -ne ($Arr | Where-Object { $Item -match $_ }))
    return $result
}

$tsenv.GetVariables() | ForEach-Object {
    if(!(MatchArrayItem -Arr $ExcludeVariables -Item $_)) {
        "$_ = $($tsenv.Value($_))" | Out-File -FilePath $logFileFullName -Append
    }
}
#endregion ????

#region Get Task Sequence Variables
ForEach ($TSVariable in $TSenv.GetVariables()) {
    $TSValue = $TSVariable.Value
    ForEach ($VariableExcluded in $VariablesExcluded) {
        If ($TSVariable.Name -like $VariableExcluded) {
            $TSValue = '~Excluded~'
            Break
        }
    }
    ForEach ($VariableSuppressed in $VariablesSuppressed) {
        If ($TSVariable.Name -like $VariableSuppressed) {
            $TSValue = '<Value suppressed for readability>'
            Break
        }
    }
    If (-not($TSValue -eq '~Excluded~')) {
		$myVariables += @{ $TSVariable.Name = $TSValue}
	}
}
#endregion Get Task Sequence Variables
#region Get Process Environment Variables
ForEach ($ENVVariable in $(Get-ChildItem env:)) {
	#TODO: ensure this is the Process' environment, not the system or user
	$myVariables += @{ ($ENVVariable.Name = $ENVVariable.Value ) }
}
#endregion Get Process Environment Variables

#region Write variables to file(s)
If ($OutputToCSV) {
	#create CSV Header
"`"Name`",`"Value`"" | Out-File -FilePath "$($LogFileBaseName).csv"

	#TODO: build the entire output in memory and write to disk once
	"`"$($TSVariable.Name)`"$CSVDelimiter`"$TSValue`"" | Out-File -FilePath "$($LogFileBaseName).csv" -Append
}
If ($OutputToLog) {
    Write-LogMessage -Message "$TSValue" -LogFile "$($LogFileBaseName).log"
}
If ($OutputToLogComponentized) {
	Write-LogMessage -Message "$TSValue" -LogFile "$($LogFileBaseName).log" -Component $TSVariable.Name
}
#endregion Write variables to file(s)