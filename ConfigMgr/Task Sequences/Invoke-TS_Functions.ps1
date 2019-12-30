#.Synopsis
#   Invoke-TS_Functions.ps1
#.Description
#.Notes
#	========== Change Log History ==========
#	- 2019/08/08 by Chad.Simmons@CatapultSystems.com - Added CMTrace style logging

<#
#region ====== Dot source the Function Library ====================================================
If ($PSise) { $global:ScriptFile = $PSise.CurrentFile.FullPath
   } Else { $global:ScriptFile = $MyInvocation.MyCommand.Definition }
# Dot source the Function Library.  Abort if dot-sourcing failed
try { ."$(Split-Path -Path $global:ScriptFile -Parent)\Invoke-TS_Functions.ps1"
    } catch { Write-Error "dot-sourcing function library failed from folder [$global:ScriptPath]"; throw $_; exit 2 }
#endregion === Dot source the Function Library ====================================================
#>

#region ====== Initialize Global Variables ============================================================================================================================================================
$global:ScriptPath = Split-Path -Path $global:ScriptFile -Parent
$global:ScriptName = Split-Path -Path $global:ScriptFile -Leaf
$global:ScriptFileItem = Get-Item -Path $global:ScriptFile
#endregion === Initialize Global Variables ============================================================================================================================================================

If ((Get-Location).Provider -ne 'Microsoft.PowerShell.Core\FileSystem') { Push-Location -Path $env:SystemRoot }

If (-not(Test-Path 'variable:global:LogFile') -or [string]::IsNullOrEmpty($global:LogFile)) { $global:LogFile=$(Join-Path -Path $global:ScriptPath -ChildPath 'SMSTS.TSFunctions.log') }

#region ====== Functions ==============================================================================================================================================================================
Function Write-LogMessageSE {
	#.Synopsis Write a log entry in CMTrace format with as little code as possible (i.e. Simplified Edition)
	param ($Message, [ValidateSet('Error','Warn','Warning','Info','Information','1','2','3')]$Type='1', $LogFile=$global:LogFile)
	If (!(Test-Path 'variable:global:LogFile')){$global:LogFile=$LogFile}
	Switch($Type){ {@('2','Warn','Warning') -contains $_}{$Type=2}; {@('3','Error') -contains $_}{$Type=3}; Default{$Type=1} }
	"<![LOG[$Message]LOG]!><time=`"$(Get-Date -F HH:mm:ss.fff)+000`" date=`"$(Get-Date -F "MM-dd-yyyy")`" component=`" `" context=`" `" type=`"$Type`" thread=`"`" file=`"`">" | Out-File -Append -Encoding UTF8 -FilePath $LogFile -WhatIf:$false
} Set-Alias -Name Write-LogMessage -Value Write-LogMessageSE
Function Write-Message ([string]$Message, $Type) {
    #.Synopsis output message to Standard Out which will display in the console or be picked up by the SCCM Task Sequence logging engine
    #TODO: Handle -Verbose
    If (-not($Quiet)) { Write-Output $Message }
    Write-LogMessage -Message $Message
}
Function Set-Var {
    #.Synopsis Set/Reset Task Sequence style variable
    Param (
        [Parameter(Mandatory=$true)][string]$Name,
        [Parameter(Mandatory=$true)][AllowNull()][AllowEmptyString()]$Value,
        [Parameter(Mandatory=$false)][string[]]$Alias,
        [Parameter(Mandatory=$false)][switch]$Force
    )
    #null values are not allowed by Task Sequence variables so convert it to blank
    If ([string]::IsNullOrEmpty($Value)) { $Value = '' }
    #Combine the variable Name and Aliases into a single array
    $Names = @(); $Names += $Name; If (-not([string]::IsNullOrEmpty($Alias) -or $Alias.count -eq 0)) { $Names += $Alias }

    Write-Verbose -Message "Setting Variable [$Name] to [$Value]$(If ($Alias) { " and creating alias for [$($Alias -join ',')]"})"
    ForEach ($Name in $Names) {
        If ($TSvars.ContainsKey($Name)) {
            $local:OldValue = $TSvars[$Name]
            If ($Force -eq $true -OR [string]::IsNullOrEmpty($TSvars[$Name])) {
                $TSvars[$Name] = $Value
                If ($OldValue -eq $TSvars[$Name]) {
                    Write-Message -Message "Variable [$Name] reset to same value of [$($TSvars[$Name])]."
                } Else {
                    Write-Message -Message "Variable [$Name] updated to [$($TSvars[$Name])].  Previously it was [$local:OldValue]."
                }
            }
        } Else {
            $TSvars.Add($Name, $Value)
            Write-LogMessage -Message "Setting Variable [$Name] to [$Value]$(If ($Alias) { " and creating alias for [$($Alias -join ',')]"})"
        }
    }
}
Function Get-TSenv {
	try {
		$global:TSenv = New-Object -ComObject Microsoft.SMS.TSEnvironment
	} catch {
		Write-Warning "Could not set/update TS Variables"
	}
}
Function Copy-HashtableToTSEnv ($Hashtable) {
	If ($TSenv) {
		#TODO: set null values to blanks
		$Hashtable.Keys | ForEach-Object {
			try {
				$TSenv.Value($_) = $Hashtable[$_]
			} catch {
				Write-Message -Message "Could not add variable [$_] as a Task Sequence variable"
			}
		}
	}
}
Function Stop-Script {
	Write-Message -Message "Script completed in $($(New-TimeSpan -Start $ScriptStartTime -End $(Get-Date)).TotalSeconds) seconds at $(Get-Date)"
	Write-Message -Message "========== Completed script [$global:ScriptFile] =========="
	Pop-Location
}
Function Start-Script {
	$global:ScriptStartTime = Get-Date
	Write-Message -Message "========== Starting script [$global:ScriptFile] =========="
	Write-Message -Message "Script modified date is $(Get-Date -Date $(($global:ScriptFileItem).LastWriteTime) -Format 'yyyy/MM/dd HH:mm:ss')"
    Write-Message -Message "Script started at $ScriptStartTime"
    Write-Verbose -Message "Log file is [$global:LogFile]"
}
#endregion === Functions ==============================================================================================================================================================================