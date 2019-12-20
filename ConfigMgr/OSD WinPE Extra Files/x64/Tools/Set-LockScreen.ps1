#.SYNOPSIS
#	Change Lock Screen and Desktop Background in Windows 10 Pro.
#.DESCRIPTION
#	This script allows you to change logon screen and desktop background in Windows 10 Professional using GPO startup script.
#.PARAMETER Force
#   Switch parameter which will restart the winlogon service to attempt an immediate update of the lock screen
#.PARAMETER ImagesPath (Optional)
#	Path to the Lock Screen images.
#   Example: "C:\Windows\Web\MyLockScreens"
#.PARAMETER ImageFileName (required)
#	File Name of the lock screen image.
#   Example: "MyNewLockScreen.jpg"
#.PARAMETER LogPath (Optional)
#   Path where save log file. If it's not specified no log is recorded.
#.EXAMPLE
#   Set-LockScreen.ps1 -ImageFileName "MyNewLockScreen.png"
#.EXAMPLE
#   Set-LockScreen.ps1 -ImagesPath "C:\Windows\Web\MyLockScreens" -ImageFileName "MyNewLockScreen.jpg" -LogPath "C:\Windows\Logs"
#.NOTES
#	========== Change Log History ==========
#	- 2019/04/25 by Chad.Simmons@CatapultSystems.com - added Force parameter to restart winlogon
#	- 2019/04/25 by Chad.Simmons@CatapultSystems.com - additional logging and verification to troubleshoot anomalies
#	- 2019/04/23 by Chad.Simmons@CatapultSystems.com - resolved issues with RedirectStandardOutput
#	- 2018/09/xx by Juan Granados 
#	=== To Do / Proposed Changes ===
#	- TODO: Add CMTrace logging in addition to Transcript logging
#
#Requires -RunAsAdministrator
Param (
    [Parameter(Mandatory=$false)][switch]$Force,
    [Parameter(Mandatory=$false,Position=0)][string]$ImagesPath,
    [Parameter(Mandatory=$true,Position=1)][ValidateNotNullOrEmpty()][string]$ImageFileName,
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
 
#set default values
$StatusValue = '1'
$RegPathPersonalizationCSP = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP'
$RegPathPersonalization = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization'
If ([string]::IsNullOrEmpty($ImagesPath)) { $ImagesPath = $executingScriptDirectory }
$LockScreenDestPath = Join-Path -Path $env:SystemRoot -ChildPath 'Web'
$LockScreenDestFile = Join-Path -Path $LockScreenDestPath -ChildPath $ImageFileName
$LockScreenSourceFile = $(Join-Path -Path $ImagesPath -ChildPath $ImageFileName)
Push-Location -Path $env:SystemDrive

#clear existing registry keys
If (Test-Path -Path $RegPathPersonalizationCSP) { Try { Remove-Item -Path $RegPathPersonalizationCSP } Catch {} }
If (Test-Path -Path $RegPathPersonalization) { Try { Remove-ItemProperty -Path $RegPathPersonalization -Name 'LockScreenImage' } Catch {} }

#copy image to permanent location
try {
    Copy-Item -Path $LockScreenSourceFile -Destination $LockScreenDestPath -Force
    Write-LogMessage -Message "Copy Lock Screen image from [$($LockScreenSourceFile)] to [$($LockScreenDestPath)]."
} catch { Write-LogMessage -Message "Failed to copy Lock Screen image from [$($LockScreenSourceFile)] to [$($LockScreenDestPath)]." -Type Error }

#set registry keys
Write-LogMessage -Message "Creating registry entries for Lock Screen"
If (-not(Test-Path $RegPathPersonalizationCSP)) {
    Write-LogMessage -Message "Creating registry path $($RegPathPersonalizationCSP)."
    New-Item -Path $RegPathPersonalizationCSP -Force | Out-Null
}
New-ItemProperty -Path $RegPathPersonalizationCSP -Name 'LockScreenImageStatus' -Value $StatusValue -PropertyType DWORD -Force | Out-Null
New-ItemProperty -Path $RegPathPersonalizationCSP -Name 'LockScreenImagePath' -Value $LockScreenDestFile -PropertyType STRING -Force | Out-Null
New-ItemProperty -Path $RegPathPersonalizationCSP -Name 'LockScreenImageUrl' -Value $LockScreenDestFile -PropertyType STRING -Force | Out-Null
$ValueCheck = (Get-ItemProperty -Path $RegPathPersonalizationCSP -Name 'LockScreenImageUrl').'LockScreenImageUrl'
If ($ValueCheck -eq $LockScreenDestFile) { Write-LogMessage -Message "LockScreenImageUrl registry updated" } Else { Write-LogMessage -Message "LockScreenImageUrl registry not updated" -Type Warn }

if (-not(Test-Path $RegPathPersonalization)) {
    Write-LogMessage -Message "Creating registry path $($RegPathPersonalization)."
    New-Item -Path $RegPathPersonalization -Force | Out-Null
}
New-ItemProperty -Path $RegPathPersonalization -Name LockScreenImage -Value $LockScreenDestFile -PropertyType STRING -Force | Out-Null
$ValueCheck = (Get-ItemProperty -Path $RegPathPersonalization -Name 'LockScreenImage').'LockScreenImage'
If ($ValueCheck -eq $LockScreenDestFile) { Write-LogMessage -Message "LockScreenImage registry updated" } Else { Write-LogMessage -Message "LockScreenImage registry not updated" -Type Warn }

If ($Force -eq $true) {
    Write-LogMessage -Message 'Restarting winlogon process'
    try {
        Stop-Process -Name winlogon -Force -ErrorAction Stop
        Start-Process -FilePath "$env:SystemRoot\System32\winlogon.exe"
    } catch { Write-LogMessage -Message 'Failed restarting winlogon process' -Type Warn }
}

Pop-Location
########################################################################################################################################################################################################
#Stop logging
Write-LogMessage -Message "========== Completing script [$executingScriptFile] =========="
Stop-Transcript -ErrorAction SilentlyContinue