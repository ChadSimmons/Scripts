#.SYNOPSIS
#	Remove Windows Lock Screen image on next logon
#.PARAMETER LogPath (Optional)
#   Path where save log file. If it's not specified no log is recorded.
#.EXAMPLE
#   Remove-LockScreen.ps1
#.EXAMPLE
#   Remove-LockScreen.ps1 -LogPath "C:\Windows\Logs"
#.NOTES
#	========== Change Log History ==========
#	- 2019/05/01 by Chad.Simmons@CatapultSystems.com - handle existing scheduled task by removing it first
#	- 2019/04/29 by Chad.Simmons@CatapultSystems.com - additional logging
#	- 2019/03/xx by Andy.Bueno@CatapultSystems.com - created
#	=== To Do / Proposed Changes ===
#	- TODO: None
#
#Requires -RunAsAdministrator
Param (
        [Parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$true)][string]$LogPath = "$env:WinDir\Logs"
)
        
Function Write-LogMessageSE {
    #.Synopsis Write a log entry in CMTrace format with as little code as possible (i.e. Simplified Edition)
    param ($Message, [ValidateSet('Error','Warn','Warning','Info','Information','1','2','3')]$Type='1', $LogFile=$script:LogFile)
    If (!(Test-Path 'variable:script:LogFile')){$script:LogFile=$LogFile}
    Switch($Type){ {@('2','Warn','Warning') -contains $_}{$Type=2}; {@('3','Error') -contains $_}{$Type=3}; Default{$Type=1} }
    "<![LOG[$Message]LOG]!><time=`"$(Get-Date -F HH:mm:ss.fff)+000`" date=`"$(Get-Date -F "MM-dd-yyyy")`" component=`" `" context=`" `" type=`"$Type`" thread=`"`" file=`"`">" | Out-File -Append -Encoding UTF8 -FilePath $LogFile -WhatIf:$false
} Set-Alias -Name Write-LogMessage -Value Write-LogMessageSE

If ($PSISE) { 
    $executingScriptFile = Split-Path -Path $PSISE.CurrentFile.FullPath -Leaf
    $executingScriptDirectory = Split-Path -Path $PSISE.CurrentFile.FullPath -Parent
} Else {
    $executingScriptDirectory = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
    $executingScriptFile = Split-Path -Path $MyInvocation.MyCommand.Definition -Leaf
}

#Start logging
$TranscriptLogFile = Join-Path -Path $LogPath -ChildPath "$([System.IO.Path]::GetFileNameWithoutExtension($executingScriptFile)).Transcript.log"
Start-Transcript -Path $TranscriptLogFile -Force -ErrorAction SilentlyContinue
$script:LogFile = Join-Path -Path $LogPath -ChildPath "$([System.IO.Path]::GetFileNameWithoutExtension($executingScriptFile)).log"
Write-LogMessage -Message "========== Starting script [$executingScriptFile] =========="
########################################################################################################################################################################################################
 
#region    ========== Schedule Lock Screen Removal
Write-LogMessage -Message 'Create a Scheduled Task to remove current lock screen on next logon'
# Name of Scheduled Task
$STName = 'Remove Lockscreen'
$TSDescription = 'Remove the Windows Setup lockscreen'
# Set up action to run
$STAction = New-ScheduledTaskAction -Execute "powershell.exe" -Argument '-ExecutionPolicy Bypass -NoProfile -NonInteractive -Command Remove-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP", "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization" -Force'
# Set up trigger to launch action
$STTrigger = New-ScheduledTaskTrigger -AtLogOn
# Set up base task settings - NOTE: Win8 is used for Windows 10
$STSettings = New-ScheduledTaskSettingsSet -Compatibility Win8 -MultipleInstances IgnoreNew -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -Hidden -StartWhenAvailable
# Remove existing Scheduled Task
try {
    $TargetTask = Get-ScheduledTask -TaskName $STName -ErrorAction Stop
    If ($TargetTask) { Unregister-ScheduledTask -TaskName $STName -ErrorAction Stop -Confirm:$false; Remove-Variable -Name TargetTask}
    Write-LogMessage -Message 'Removed existing Scheduled Task'
} catch { }
# Create Scheduled Task
try { Register-ScheduledTask -Action $STAction -Trigger $STTrigger -Settings $STSettings -TaskName $STName -Description $TSDescription -User 'NT AUTHORITY\SYSTEM' -RunLevel Highest -ErrorAction Stop | Out-Null
    # Get the Scheduled Task data and make some tweaks
    $TargetTask = Get-ScheduledTask -TaskName $STName
    # Set desired tweaks
    $TargetTask.Author = 'IT Support'
    $TargetTask.Triggers[0].StartBoundary = [DateTime]::Now.AddHours(-4).ToString("yyyy-MM-dd'T'HH:mm:ss")
    $TargetTask.Triggers[0].EndBoundary = [DateTime]::Now.AddDays(7).ToString("yyyy-MM-dd'T'HH:mm:ss")
    #$TargetTask.Triggers[0].Repetition.Duration = 'PT60M'
    #$TargetTask.Triggers[0].Repetition.Interval = 'PT05M'
    #$TargetTask.Settings.DeleteExpiredTaskAfter = 'PT1440M'
    $TargetTask.Settings.ExecutionTimeLimit = 'PT60M'
    $TargetTask.Settings.volatile = $False
    $TargetTask.Settings.RestartCount = 9
    $TargetTask.Settings.RestartInterval = 'PT01M'
    $TargetTask.Settings.AllowHardTerminate = $False
    $TargetTask.Settings.DeleteExpiredTaskAfter = 'P1D'
    $TargetTask.Settings.StartWhenAvailable = $True
    # Save tweaks to the Scheduled Task
    try { $TargetTask | Set-ScheduledTask -ErrorAction Stop } 
        catch { Write-LogMessage -Message 'Failed creating a Scheduled Task to remove current lock screen on next logon' -Type Error; Throw $_ }
} catch { Write-LogMessage -Message 'Failed creating a Scheduled Task to remove current lock screen on next logon' -Type Error; Throw $_ }
#endregion ========== Schedule Lock Screen Removal

########################################################################################################################################################################################################
#Stop logging
Write-LogMessage -Message "========== Completing script [$executingScriptFile] =========="
Stop-Transcript -ErrorAction SilentlyContinue

