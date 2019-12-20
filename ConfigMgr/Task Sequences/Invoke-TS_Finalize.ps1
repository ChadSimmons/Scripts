### !!! Customize region Environment specific variables !!! ###
#.Synopsis
#   Invoke-TS_Finalize.ps1
#   Set built-in and custom SCCM Task Sequence Variable defaults.
#   This should be run at the end of a Task Sequence before logging TS variables and uploading logs
#   This should be run after Invoke-TS_Initialize.ps1
#.Description
#.Parameter Quiet
#    Suppressed writing the Variables and Values to standard out
#.Example
#    PowerShell.exe -ExecutionPolicy Bypass -File Invoke-TS_Finalize.ps1
#.Notes
#	========== Change Log History ==========
#	- 2019/07/25 by Chad.Simmons@CatapultSystems.com - minor updates
#	- 2019/06/11 by Chad.Simmons@CatapultSystems.com - added SCCM/ConfigMgr Client Actions and additional logging
#	- 2019/05/30 by Chad.Simmons@CatapultSystems.com - minor updates
#	- 2019/05/22 by Chad.Simmons@CatapultSystems.com - Created
#	=== To Do / Proposed Changes ===
#	- TODO: None
#	=== Additional Notes and References ===
[CmdletBinding()]
param (
    [switch]$Quiet
)

#region ====== Dot source the Function Library ====================================================
If ($PSise) {
 $global:ScriptFile = $PSise.CurrentFile.FullPath
} Else { $global:ScriptFile = $MyInvocation.MyCommand.Definition }
# Dot source the Function Library.  Abort if dot-sourcing failed
try {
 ."$(Split-Path -Path $global:ScriptFile -Parent)\Invoke-TS_Functions.ps1"
} catch { Write-Error "dot-sourcing function library failed from folder [$global:ScriptPath]"; throw $_; exit 2 }
#endregion === Dot source the Function Library ====================================================

########################################################################################################################################################################################################
########################################################################################################################################################################################################
If ((Get-Location).Provider -ne 'Microsoft.PowerShell.Core\FileSystem') { Push-Location -Path $env:SystemRoot }
Start-Script
$TSvars = @{}
If (-not($TSenv)) {
    try {
        $TSenv = New-Object -ComObject Microsoft.SMS.TSEnvironment
    } catch { }
}

#region    ========== Common Variables
Set-Var -Name 'zTS_FinishTime' -Value $(Get-Date -Format 'yyyyMMddHHmmss') -Force
Set-Var -Name 'zTS_FinishTimestamp' -Value $(Get-Date -Format 's') -Force

If ($TSenv) {
	try {
        Write-Message -Message 'Setting default variables and values'
        #Set-Var -Name 'zTS_LastActionSucceeded' -Value $TSenv.Value('_SMSTSLastActionSucceeded')
        #Set-Var -Name 'zTS_LastActionReturnCode' -Value $TSenv.Value('_SMSTSLastActionRetCode')
        #Set-Var -Name 'zTS_LastActionName' -Value $TSenv.Value('_SMSTSLastActionName')
        #Set-Var -Name 'zTS_ErrorMessageTitle' -Value 'Failed with error ' + $TSenv.Value('_SMSTSLastActionRetCode') + ' on step ' + $TSenv.Value('_SMSTSLastActionName')
        If ($TSenv.Value('zTS_FinalStatus') -ne 'Failed') {
            Set-Var -Name 'zTS_FinalStatus' -Value 'Success' -Force
            If ($TSenv.Value('zTS_FinalReturnCode') -ne '3010') {
                Set-Var -Name 'zTS_FinalReturnCode' -Value '0' -Force
            }
        }
        #TODO: consider this... but does not fit in variable management model... Set before updating zTS_LogsFinalPath...
        #try { $TSenv.Value('zTS_FinalStatus') = $TSvars['zTS_FinalStatus'] } catch {}
        #Set-Var -Name 'zTS_LogsFinalPath' -Value "$($TSenv.Value('zTS_TSType'))-$($TSenv.Value('_SMSTSPackageID'))-$($TSenv.Value('zTS_FinalStatus'))" -Force
        Set-Var -Name 'zTS_LogsFinalPath' -Value "$($TSenv.Value('zTS_TSType'))-$($TSenv.Value('_SMSTSPackageID'))-$($TSvars['zTS_FinalStatus'])" -Force
    } catch {
        Write-Warning -Message 'Could not set Task Sequence variable(s).'
    }
} Else {
    Write-Warning -Message 'Not running within a Task Sequence.'
}
#endregion ========== Common Variables

#region    ========== Environment specific variables
#Set-Var -Name 'zTS_OrgName' -Value 'LAB' #This is already set in Invoke-TS_Initialize.ps1
#endregion ========== Environment specific variables

#Set-OSDInfo.ps1 -Registry -WMI -ID 'OSBuild'


#region    ========== Validate Task Sequence success
#TODO: Validate Task Sequence success
#Get 1E AppMigration list from SMSTS.log
#Get Software Install Successes from SMSTS.log
#Get Software Install Failures from SMSTS.log
#Get TPM settings from BIOS
#Get BitLocker status
#Get USMT Restore status
#Log status in SMSTS.log
#Log status in local file/registry key/WMI class
#Log status in UNC path file
#endregion ========== Validate Task Sequence success


#region    ========== Copy set variables to Task Sequence environment variables
If ($TSenv) {
    Copy-HashtableToTSEnv -Hashtable $TSvars
}
#endregion  ========== Copy set variables to Task Sequence environment variables

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

#region    ========== Tag registry
If ($TSenv) {
        $RegPath = "HKLM:\SOFTWARE\$($TSenv.Value('zTS_OrgName'))\TaskSequences\$($TSenv.Value('_SMSTSPackageID'))"
        Write-Message -Message "Writing key Task Sequence Variables to the registry at [$RegPath] (overwrite delete existing)"
        New-Item -Path $RegPath -Force | out-null
        New-ItemProperty -Path $RegPath -Name 'FinishTime' -Value $TSenv.Value('zTS_FinishTime') -PropertyType String -Force -ErrorAction SilentlyContinue | out-null
        New-ItemProperty -Path $RegPath -Name 'StartTime' -Value $TSenv.Value('zTS_StartTime') -PropertyType String -Force -ErrorAction SilentlyContinue | out-null
        New-ItemProperty -Path $RegPath -Name 'FinishTimestamp' -Value $TSenv.Value('zTS_FinishTimestamp') -PropertyType String -Force -ErrorAction SilentlyContinue | out-null
        New-ItemProperty -Path $RegPath -Name 'StartTimestamp' -Value $TSenv.Value('zTS_StartTimestamp') -PropertyType String -Force -ErrorAction SilentlyContinue | out-null
        New-ItemProperty -Path $RegPath -Name 'TSVersion' -Value $TSenv.Value('zTS_TSVersion') -PropertyType String -Force -ErrorAction SilentlyContinue | out-null
        New-ItemProperty -Path $RegPath -Name 'TSType' -Value $TSenv.Value('zTS_TSType') -PropertyType String -Force -ErrorAction SilentlyContinue | out-null
        New-ItemProperty -Path $RegPath -Name 'FinalStatus' -Value $TSenv.Value('zTS_FinalStatus') -PropertyType String -Force -ErrorAction SilentlyContinue | out-null
        #New-ItemProperty -Path $RegPath -Name '_SMSTSLastActionName' -Value $TSenv.Value('_SMSTSLastActionName') -PropertyType String -Force -ErrorAction SilentlyContinue | out-null
        #New-ItemProperty -Path $RegPath -Name '_SMSTSLastActionSucceeded' -Value $TSenv.Value('_SMSTSLastActionSucceeded') -PropertyType String -Force -ErrorAction SilentlyContinue | out-null
        #New-ItemProperty -Path $RegPath -Name '_SMSTSLastActionRetCode' -Value $TSenv.Value('_SMSTSLastActionRetCode') -PropertyType String -Force -ErrorAction SilentlyContinue | out-null
}
#endregion ========== Tag registry

#region    ========== SCCM/ConfigMgr Client Actions
Write-Message -Message "Invoking SCCM/ConfigMgr Client Actions to update inventory"
#SCCM/ConfigMgr Discovery Data Collection Cycle
Invoke-WMIMethod -Namespace root\ccm -Class SMS_CLIENT -Name TriggerSchedule '{00000000-0000-0000-0000-000000000003}' -ErrorAction SilentlyContinue | Out-Null
#SCCM/ConfigMgr Hardware Inventory Cycle
Invoke-WMIMethod -Namespace root\ccm -Class SMS_CLIENT -Name TriggerSchedule '{00000000-0000-0000-0000-000000000001}' -ErrorAction SilentlyContinue | Out-Null
#endregion ========== SCCM/ConfigMgr Client Actions

Stop-Script