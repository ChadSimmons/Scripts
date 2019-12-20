#.Synopsis
#   Invoke-TS_LogParser.ps1
#   Parse the SMSTS.log and related logs for specific events and errors
#.Description
#.Parameter ???
#    ???
#.Example
#    PowerShell.exe -ExecutionPolicy Bypass -File Invoke-TS_LogParser.ps1
#.Notes
#	========== Change Log History ==========
#	- 2019/07/03 by Chad.Simmons@CatapultSystems.com - Created
#	=== To Do / Proposed Changes ===
#	- TODO: None
#	=== Additional Notes and References ===
[CmdletBinding()]
param (
    [switch]$Quiet
)
########################################################################################################################################################################################################
Function Write-LogMessage ([string]$Message, $Type) {
    #.Synopsis output message to Standard Out which will display in the console or be picked up by the SCCM Task Sequence logging engine
    #TODO: Handle -Verbose
    If (-not($Quiet)) { Write-Output $Message }
}
Function Set-Var {
    #.Synopsis Set/Reset Task Sequence style variable
    Param (
        [Parameter(Mandatory=$true)][string]$Name,
        [Parameter(Mandatory=$true)][AllowNull()][AllowEmptyString()]$Value,
        [Parameter(Mandatory=$false)][string[]]$Alias,
        [Parameter(Mandatory=$false)][switch]$Force
    )
    If ([string]::IsNullOrEmpty($Value)) { $Value = '' }
    If ($TSvars.ContainsKey($Name)) {
        $local:OldValue = $TSvars[$Name]
        If ($Force -eq $true -OR [string]::IsNullOrEmpty($TSvars[$Name])) {
            $TSvars[$Name] = $Value
            If ($null -ne $Alias) { $Alias | ForEach-Object { $TSvars.Add($_, $Value) } }
            If ($OldValue -eq $TSvars[$Name]) {
                Write-LogMessage -Message "Variable [$Name] reset to same value of [$($TSvars[$Name])]."
            } Else {
                Write-LogMessage -Message "Variable [$Name] updated to [$($TSvars[$Name])].  Previously it was [$local:OldValue]."
            }
        }
    } Else {
        $TSvars.Add($Name, $Value)
        If ($null -ne $Alias) { $Alias | ForEach-Object { $TSvars.Add($_, $Value) } }
    }
}
########################################################################################################################################################################################################
If ((Get-Location).Provider -ne 'Microsoft.PowerShell.Core\FileSystem') { Push-Location -Path $env:SystemRoot }

If ($PSise) {
    $script:ScriptFile = $PSise.CurrentFile.FullPath
} Else {
    $script:ScriptFile = $MyInvocation.MyCommand.Definition
}
$script:ScriptPath = Split-Path -Path $script:ScriptFile -Parent
$script:ScriptName = Split-Path -Path $script:ScriptFile -Leaf
$script:ScriptFileItem = Get-Item -Path $script:ScriptFile

Write-LogMessage -Message "========== Starting script [$script:ScriptFile] =========="
Write-LogMessage -Message "Script modified date is $(Get-Date -Date $(($script:ScriptFileItem).LastWriteTime) -Format 'yyyy/MM/dd HH:mm:ss')"

$TSvars = @{}

#region    ========== Common Variables
#Set-Var -Name 'zTS_FinishTime' -Value $(Get-Date -Format 'yyyyMMddHHmmss')
#Set-Var -Name 'zTS_FinishTimestamp' -Value $(Get-Date -Format 's')
#
#try {
#    $TSenv = New-Object -ComObject Microsoft.SMS.TSEnvironment
#    Write-LogMessage -Message 'Setting default variables and values'
#    #Set-Var -Name 'zTS_LastActionSucceeded' -Value $TSenv.Value('_SMSTSLastActionSucceeded')
#    #Set-Var -Name 'zTS_LastActionReturnCode' -Value $TSenv.Value('_SMSTSLastActionRetCode')
#    #Set-Var -Name 'zTS_LastActionName' -Value $TSenv.Value('_SMSTSLastActionName')
#    #Set-Var -Name 'zTS_ErrorMessageTitle' -Value 'Failed with error ' + $TSenv.Value('_SMSTSLastActionRetCode') + ' on step ' + $TSenv.Value('_SMSTSLastActionName')
#    If ($TSenv.Value('zTS_FinalStatus') -ne 'Failed') {
#        Set-Var -Name 'zTS_FinalStatus' -Value 'Success'
#        If ($TSenv.Value('zTS_FinalReturnCode') -ne '3010') {
#            Set-Var -Name 'zTS_FinalReturnCode' -Value '0'
#        }
#    }
#    Set-Var -Name 'zTS_LogsFinalPath' -Value "$($TSenv.Value('zTS_TSType'))-$($TSenv.Value('_SMSTSPackageID'))-$($TSenv.Value('zTS_FinalStatus'))"
#} catch { }
#endregion ========== Common Variables

#region    ========== Environment specific variables
#Set-Var -Name 'zTS_OrgName' -Value 'LAB' #This is already set in Invoke-TS_Initialize.ps1
#endregion ========== Environment specific variables

##region    ========== Copy set variables to Task Sequence environment variables
#try {
#    $TSenv = New-Object -ComObject Microsoft.SMS.TSEnvironment
#    Write-LogMessage -Message 'Copying script variable to Task Sequence environment variables'
#} catch {
#    Write-LogMessage -Message 'Failure copying script variable to Task Sequence environment variables'
#}
#If ($TSenv) {
#    $TSvars.Keys | ForEach-Object {
#        try {
#           $TSenv.Value($_) = $TSvars[$_] #-ErrorAction Stop
#        } catch {
#            #TODO: $_ doesn't work here... Write-Warning "Could not set/update TS Variable [$_] to [$($TSvars[$_])]"
#        }
#    }
#}
##endregion  ========== Copy set variables to Task Sequence environment variables

#region     ========== Output set variables
If (-not($Quiet)) {
    $TSvars.Keys | Sort-Object | ForEach-Object { Write-Output "$($_) = $($TSvars[$_])" }
    If ($TSenv) {
        #Output additional Task Sequence variables of interest
        $TSVariables = @('_SMSTSOSUpgradeActionReturnCode','SMSTSRebootRequested','SMSTS_HardBlocker')
        $TSVariables | ForEach-Object { If ($TSenv.Value($_)) { Write-Output "$($_) = $($TSenv.Value($_))" } }
        Remove-Variable -Name TSVariables -ErrorAction SilentlyContinue
    }
}
#endregion  ========== Output set variables

##region    ========== Tag registry
#try {
#    $TSenv = New-Object -ComObject Microsoft.SMS.TSEnvironment
#    $RegPath = "HKLM:\SOFTWARE\$($TSenv.Value('zTS_OrgName'))\TaskSequences\$($TSenv.Value('_SMSTSPackageID'))"
#    Write-LogMessage -Message "Writing key Task Sequence Variables to the registry at [$RegPath] (overwrite delete existing)"
#    New-Item -Path $RegPath -Force | out-null
#    New-ItemProperty -Path $RegPath -Name 'FinishTime' -Value $TSenv.Value('zTS_FinishTime') -PropertyType String -Force -ErrorAction SilentlyContinue | out-null
#    New-ItemProperty -Path $RegPath -Name 'StartTime' -Value $TSenv.Value('zTS_StartTime') -PropertyType String -Force -ErrorAction SilentlyContinue | out-null
#    New-ItemProperty -Path $RegPath -Name 'FinishTimestamp' -Value $TSenv.Value('zTS_FinishTimestamp') -PropertyType String -Force -ErrorAction SilentlyContinue | out-null
#    New-ItemProperty -Path $RegPath -Name 'StartTimestamp' -Value $TSenv.Value('zTS_StartTimestamp') -PropertyType String -Force -ErrorAction SilentlyContinue | out-null
#    New-ItemProperty -Path $RegPath -Name 'TSVersion' -Value $TSenv.Value('zTS_TSVersion') -PropertyType String -Force -ErrorAction SilentlyContinue | out-null
#    New-ItemProperty -Path $RegPath -Name 'TSType' -Value $TSenv.Value('zTS_TSType') -PropertyType String -Force -ErrorAction SilentlyContinue | out-null
#    New-ItemProperty -Path $RegPath -Name 'FinalStatus' -Value $TSenv.Value('zTS_FinalSatus') -PropertyType String -Force -ErrorAction SilentlyContinue | out-null
#    #New-ItemProperty -Path $RegPath -Name '_SMSTSLastActionName' -Value $TSenv.Value('_SMSTSLastActionName') -PropertyType String -Force -ErrorAction SilentlyContinue | out-null
#    #New-ItemProperty -Path $RegPath -Name '_SMSTSLastActionSucceeded' -Value $TSenv.Value('_SMSTSLastActionSucceeded') -PropertyType String -Force -ErrorAction SilentlyContinue | out-null
#    #New-ItemProperty -Path $RegPath -Name '_SMSTSLastActionRetCode' -Value $TSenv.Value('_SMSTSLastActionRetCode') -PropertyType String -Force -ErrorAction SilentlyContinue | out-null
#} catch { }
##endregion ========== Tag registry

Write-LogMessage -Message "========== Completed script [$script:ScriptFile] =========="
Pop-Location