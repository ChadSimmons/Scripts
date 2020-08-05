################################################################################
#.SYNOPSIS
#   Set-DataDeduplication.ps1
#   Enable Windows Server Data Deduplication excluding ConfigMgr/SCCM Content Source Folders, the ConfigMgr install folder, and SQL Server install, data, and log folders
#.PARAMETER Drive
#   Specifies the drive to dedupe.
#.EXAMPLE
#   Set-DataDeduplication.ps1 -Drive 'E'
#.LINK
#   https://cloudblogs.microsoft.com/enterprisemobility/2014/02/18/configuration-manager-distribution-points-and-windows-server-2012-data-deduplication
#   https://deploymentresearch.com/Research/Post/409/Using-Data-DeDuplication-with-ConfigMgr-2012-R2
#   http://wmug.co.uk/wmug/b/r0b/archive/2014/02/21/windows-2012-server-deduplication-and-configmgr-2012
#   https://docs.microsoft.com/en-us/previous-versions/windows/it-pro/windows-server-2012-R2-and-2012/hh831434(v=ws.11)
#   https://docs.microsoft.com/en-us/windows-server/storage/data-deduplication/install-enable
#.NOTES
#   This script is maintained at https: //github.com/ChadSimmons/Scripts
#   Additional information about the function or script.
#   ========== Change Log History ==========
#   - 2018/09/25 by Chad.Simmons@CatapultSystems.com - updated ValidatePattern and IncludeFolders
#   - 2016/12/21 by Chad.Simmons@CatapultSystems.com - Created
#   - 2016/12/21 by Chad@ChadsTech.net - Created
################################################################################
#region    ######################### Parameters and variable initialization ####
    [CmdletBinding()] #(SupportsShouldProcess=$false, ConfirmImpact="Low")
    Param (
        [Parameter(Mandatory=$true)][ValidateLength(1,1)][ValidatePattern('[d-zD-Z]')][ValidateScript({Test-Path "$_\" -PathType 'Container'})]
        [string]$Drive = 'E'
    )
    #region    ######################### Debug code
        <#
        $Drive = 'D'
        #>
    #endregion ######################### Debug code

If ($Drive -notlike '*:') { $Drive = $Drive + ':'}

$CustomNoCompressionFileTypes = @('7z','mp3','mp4','mkv','jpg','png','zpaq','bak','wim')
$IncludeFolders = @('SCCMContentLib','SMS_DP$',"SMSPKG$($Drive)$",'SMSPKGSIG','SMSSIG$','Backup','Install','Installs')
$ExcludeFolders = (Get-ChildItem -Path "$Drive\" -Directory | Where-Object { $_.Name -notin $IncludeFolders }).Name  #All non-included root folders
#endregion #####################################################################

try {
	Write-Output 'Install the Windows feature'
	Import-Module ServerManager
    $Result = Add-WindowsFeature -Name FS-Data-Deduplication
    If ($Result.RestartNeeded -eq 'Yes') {
        Write-Warning 'Restart Required'
        break
    }
    Write-Output 'Import PowerShell Module'
	Import-Module Deduplication
	Write-Output 'Enable on volume'
    Enable-DedupVolume $Drive

    try {
	    Write-Output 'Set exclusions'
        Set-DedupVolume –Volume $Drive -ExcludeFolder @((Get-DedupVolume -Volume $Drive | Select-Object -ExpandProperty ExcludeFolder) + @($ExcludeFolders | ForEach-Object { "`\$_" }))
        Set-DedupVolume –Volume $Drive -NoCompressionFileType @(@(Get-DedupVolume -Volume $Drive | Select-Object -ExpandProperty NoCompressionFileType) + $CustomNoCompressionFileTypes)
	    Write-Output 'Start deduplication and monitor progress'
    	Start-DedupJob –Volume $Drive -Type Optimization -Preempt
    	Get-DedupJob -Volume $Drive
    	Get-DedupStatus -Volume $Drive
    } catch {
	    Write-Error $_
    }
} catch {
	Write-Error $_
}
Write-Output 'Show the existing / built-in schedules'
Get-DedupSchedule
Get-DedupVolume -Volume $Drive | Select-Object -ExpandProperty NoCompressionFileType
Get-DedupVolume -Volume $Drive | Select-Object -ExpandProperty ExcludeFolder
Get-DedupVolume -Volume $Drive | Select-Object Volume, Enabled, MinimumFileAgeDays, MinimumFileSize, NoCompress, OptimizeInUseFiles, SavedSpace, SavingsRate, UnoptimizedSize, UsedSpace
Write-Output "=== OPTIONAL ===`nSet-DedupSchedule -Name Daily -Cores 1 -Days @('Sunday','Monday','Tuesday','Wednesday','Thursday','Friday','Saturday') -DurationHours 4 -Enabled -Memory 50 -Priority Low -StopWhenSystemBusy $true -Type Optimization -Start 01:45"
