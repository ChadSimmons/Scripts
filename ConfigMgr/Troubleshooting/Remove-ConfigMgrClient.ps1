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
#   Remove-ConfigMgrClient.ps1
#   run ConfigMgr's uninstall command and cleanup leftover files, registry keys, and certificates
#.DESCRIPTION
#   Log high-level actions to C:\Windows\Logs\CCMSetup-Uninstall.log
#   Stop ConfigMgr services
#   Copy CMTrace to C:\Windows to preserve it as a troubleshooting tool
#   Execute CCMsetup.exe /uninstall
#   Remove ConfigMgr services from registry
#   Remove ConfigMgr Client from registry
#   Remove leftover folders and files
#   Remove ConfigMgr Start Menu Software Center shortcut and empty folder
#   Remove ConfigMgr self-signed certificates
#   If -Force parameter used
#      Remove WMI Namespaces
#      Remove Windows Update Agent policies and rely on GPO or MDM to reapply them
#      Reset MDM Authority
#.Parameter Force
#   remove WMI classes, reset MDM Authority, and reset WSUS policy
#.Parameter LogFile
#   Folder path for input, output, and logs
#   Defaults to C:\Windows\Logs\CCMSetup-Uninstall.log
#.EXAMPLE
#   Remove-ConfigMgrClient.ps1
#   Run script with default settings
#.EXAMPLE
#   Remove-ConfigMgrClient.ps1 -Force -LogFile C:\Windows\Logs\Remove-ConfigMgrClient.log
#   Run script and force uninstall/cleanup with a custom log file
#.NOTES
#   This script is maintained at https://github.com/ChadSimmons/Scripts
#   ========== Keywords =========================
#   Keywords: MECM MEMCM SCCM Configuration Manager client agent uninstall remove removal cleanup
#   ========== Change Log History ===============
#   - 2021/11/15 by Chad.Simmons@CatapultSystems.com - added log file backup, granular parameters, GPO and MDM policy update/sync
#   - 2021/11/08 by Chad.Simmons@CatapultSystems.com - rewrote entirely
#   - 2018/11/30 by @robertomoir on GitHub - based on https://github.com/robertomoir/remove-sccm/blob/master/remove-sccmagent.ps1
#   ========== To Do / Proposed Changes =========
#   - #TODO: backup leftover registry keys, files, folders, certificates and other identifying configuration items before uninstalling
#   ===== Additional References and Reading =====
#   - CCMSetup.exe client installation parameters https://docs.microsoft.com/en-us/mem/configmgr/core/clients/deploy/about-client-installation-properties#uninstall
#   - Remove INI and Certificates https://docs.microsoft.com/en-us/mem/configmgr/core/clients/deploy/deploy-clients-to-windows-computers#prepare-the-client-computer-for-imaging
########################################################################################################################
#region ############# Parameters and variable initialization ############################## #BOOKMARK: Script Parameters
[CmdletBinding()]
Param (
  [Parameter(Mandatory = $false, HelpMessage = 'remove cached machine GPOs (registry.pol)')][switch]$ResetGPO,
  [Parameter(Mandatory = $false, HelpMessage = 'remove ConfigMgr client WMI namespaces')][switch]$ResetWMI,
  [Parameter(Mandatory = $false, HelpMessage = 'remove Windows Update Agent registry keys and update GPO/MDM')][switch]$ResetWUPolicy,
  [Parameter(Mandatory = $false, HelpMessage = 'remove MDM Authority registry keys and update GPO/MDM ')][switch]$ResetMDM,
  [Parameter(Mandatory = $false, HelpMessage = 'remove WMI classes, reset MDM Authority, and reset WSUS policy')][switch]$Force,
  [Parameter(Mandatory = $false, HelpMessage = 'Folder path for input, output, and logs')][Alias('Log')][string]$LogFile = "$env:SystemRoot\Logs\CCMSetup-Uninstall.log"
)
#endregion ########## Parameters and variable initialization ###########################################################

#region ############# Functions ############################################################ #BOOKMARK: Script Functions
########################################################################################################################
########################################################################################################################
Function Start-Script ([parameter(Mandatory = $true)][string]$ScriptFile) {
  #.Synopsis Gather information about the script and write the log header information
  $script:ScriptFile = $ScriptFile
  $script:ScriptPath = Split-Path -Path $script:ScriptFile -Parent
  $script:ScriptFileName = Split-Path -Path $script:ScriptFile -Leaf
  If ([string]::IsNullOrEmpty($script:LogFile)) { $script:LogFile = [System.IO.Path]::ChangeExtension($ScriptFile, 'log') }
  Write-LogMessage -Message "==================== Starting Script ===================="
  Write-LogMessage -Message "Script Info...`n   Script file [$script:ScriptFile]`n   Log file [$LogFile]`n   Computer [$env:ComputerName]`n   Start time [$(Get-Date -Format 'F')]" -Console
}
Function Write-LogMessageSE {
  #.Synopsis Write a log entry in CMTrace format with as little code as possible (i.e. Simplified Edition)
  param ($Message, [ValidateSet('Error', 'Warn', 'Warning', 'Info', 'Information', '1', '2', '3')]$Type = '1', $LogFile = $script:LogFile, [switch]$Console)
  If (!(Test-Path 'variable:script:LogFile')) { $script:LogFile = $LogFile }
  Switch ($Type) { { @('2', 'Warn', 'Warning') -contains $_ } { $Type = 2 }; { @('3', 'Error') -contains $_ } { $Type = 3 }; Default { $Type = 1 } }
  "<![LOG[$Message]LOG]!><time=`"$(Get-Date -F HH:mm:ss.fff)+000`" date=`"$(Get-Date -F 'MM-dd-yyyy')`" component=`" `" context=`" `" type=`"$Type`" thread=`"`" file=`"`">" | Out-File -Append -Encoding UTF8 -FilePath $LogFile -WhatIf:$false
  If ($Console) { Write-Host "[$(Get-Date -F HH:mm:ss.fff)] $Message" }
}; Set-Alias -Name 'Write-LogMessage' -Value 'Write-LogMessageSE' -Confirm:$false -Force
########################################################################################################################
########################################################################################################################
#endregion ########## Functions ########################################################################################


#region ############# Initialize ########################################################## #BOOKMARK: Script Initialize
Start-Script -ScriptFile $(If ($PSise) { $PSise.CurrentFile.FullPath } Else { $MyInvocation.MyCommand.Definition })
#endregion ########## Initialization ###################################################################################
#region ############# Main Script ############################################################### #BOOKMARK: Script Main

# Stop Services and wait for exit
Write-LogMessage -Message 'Stopping ConfigMgr services ccmsetup, ccmexec, smstsmgr, cmrcservice'
Stop-Service -Name ccmsetup -Force -ErrorAction SilentlyContinue
Stop-Service -Name CcmExec -Force -ErrorAction SilentlyContinue
Stop-Service -Name smstsmgr -Force -ErrorAction SilentlyContinue
Stop-Service -Name CmRcService -Force -ErrorAction SilentlyContinue

# Preserve CMTrace.exe log file viewer
Write-LogMessage -Message 'Preserving CMTrace.exe log file viewer'
try {
  Copy-Item -Path "$env:SystemRoot\CCM\CMTrace.exe" -Destination $env:SystemRoot -ErrorAction SilentlyContinue
  Write-LogMessage -Message "Copied CMTrace.exe to [$($env:SystemRoot)]"
} catch {}


# Backup ConfigMgr Client logs
Write-LogMessage -Message "Archiving ConfigMgr Client logs to [$(""$env:SystemRoot\Logs"")] before uninstalling"
try {
  $TempPath = Join-Path -Path $env:Temp -ChildPath 'ConfigMgrClientLogs'
  [void](New-Item -Path $TempPath -ItemType Directory -ErrorAction Stop)
  Copy-Item -Path "$env:SystemRoot\CCM\Logs\*.*" -Destination "$TempPath\" -ErrorAction SilentlyContinue
  Copy-Item -Path "$env:SystemRoot\SMSCFG.ini" -Destination "$TempPath\" -ErrorAction SilentlyContinue
  Add-Type -Assembly 'System.IO.Compression.FileSystem'
  [System.IO.Compression.ZipFile]::CreateFromDirectory("$TempPath", "$env:SystemRoot\Logs\ConfigMgrClient.zip", $([System.IO.Compression.CompressionLevel]::Optimal), $false)
  [void](Remove-Item -Path $TempPath -Recurse -Force -ErrorAction SilentlyContinue)
} catch {
  Write-LogMessage -Message "Archiving ConfigMgr Client logs did not succeed" -Type Warning
}

# Run ConfigMgr client uninstall
# Get the path to ConfigMgr client's installer/uninstaller
$CCMSetupPath = Join-Path -Path $env:SystemRoot -ChildPath 'ccmsetup\ccmsetup.exe'
# If it exists run it, or else we will silently fail
If (Test-Path $CCMSetupPath) {
  Write-LogMessage -Message 'Executing CCMsetup.exe /uninstall'
  Start-Process -FilePath "$CCMSetupPath" -ArgumentList '/uninstall' -NoNewWindow #-Verb RunAs #-Wait
  # wait for exit
  try {
    $CCMSetupProcess = Get-Process -Name ccmsetup -ErrorAction Stop
		  $CCMSetupProcess.WaitForExit()
  } Catch { }
} Else {
  Write-LogMessage -Message 'CCMsetup.exe not found'
}

# Backup ConfigMgr Client Setup logs
Write-LogMessage -Message "Archiving ConfigMgr Client Setup logs to [$(""$env:SystemRoot\Logs"")]"
try {
  $TempPath = Join-Path -Path $env:Temp -ChildPath 'ConfigMgrClientLogs'
  [void](New-Item -Path $TempPath -ItemType Directory -ErrorAction Stop)
  Copy-Item -Path "$env:SystemRoot\CCMSetup\Logs\*.*" -Destination "$TempPath\" -ErrorAction SilentlyContinue
  Add-Type -Assembly 'System.IO.Compression.FileSystem'
  [System.IO.Compression.ZipFile]::CreateFromDirectory("$TempPath", "$env:SystemRoot\Logs\ConfigMgrClientSetup.zip", $([System.IO.Compression.CompressionLevel]::Optimal), $false)
  [void](Remove-Item -Path $TempPath -Recurse -Force -ErrorAction SilentlyContinue)
} catch {
  Write-LogMessage -Message "Archiving ConfigMgr Client Setup logs did not succeed" -Type Warning
}

# Remove ConfigMgr services from registry
Write-LogMessage -Message 'Remove ConfigMgr services from registry'
$RegistryPath = 'HKLM:\SYSTEM\CurrentControlSet\Services'
Remove-Item -Path $RegistryPath\CCMSetup -Force -Recurse -ErrorAction SilentlyContinue
Remove-Item -Path $RegistryPath\CcmExec -Force -Recurse -ErrorAction SilentlyContinue
Remove-Item -Path $RegistryPath\SMSTSMgr -Force -Recurse -ErrorAction SilentlyContinue
Remove-Item -Path $RegistryPath\CmRcService -Force -Recurse -ErrorAction SilentlyContinue

# Remove ConfigMgr Client from registry
Write-LogMessage -Message 'Remove ConfigMgr Client from registry'
$RegistryPath = 'HKLM:\SOFTWARE\Microsoft'
Remove-Item -Path $RegistryPath\SMS -Force -Recurse -ErrorAction SilentlyContinue
Remove-Item -Path $RegistryPath\CCM -Force -Recurse -ErrorAction SilentlyContinue
Remove-Item -Path $RegistryPath\CCMSetup -Force -Recurse -ErrorAction SilentlyContinue

# Remove leftover folders and files
Write-LogMessage -Message 'Remove leftover folders and files'
Remove-Item -Path "$env:SystemRoot\CCM" -Force -Recurse -ErrorAction SilentlyContinue
Remove-Item -Path "$env:SystemRoot\ccmsetup" -Force -Recurse -ErrorAction SilentlyContinue
Remove-Item -Path "$env:SystemRoot\ccmcache" -Force -Recurse -ErrorAction SilentlyContinue
Remove-Item -Path "$env:SystemRoot\SMSCFG.ini" -Force -ErrorAction SilentlyContinue
Remove-Item -Path "$env:SystemRoot\SMS*.mif" -Force -ErrorAction SilentlyContinue

# Remove ConfigMgr Start Menu Software Center shortcut and empty folder
Write-LogMessage -Message 'Remove ConfigMgr Start Menu Software Center shortcut and empty folder'
$MSCStartMenuPath = Join-Path -Path $([system.environment]::GetFolderPath('CommonPrograms')) -ChildPath 'Microsoft System Center\Configuration Manager'
If (Test-Path -Path "$MSCStartMenuPath\Software Center.lnk") { Remove-Item -Path "$MSCStartMenuPath\Software Center.lnk" -Force -ErrorAction SilentlyContinue }
$Files = @(Get-ChildItem -Path $MSCStartMenuPath -Filter '*.lnk' -File -Recurse -ErrorAction SilentlyContinue)
If ($Files.count -eq 0) { Remove-Item -Path "$MSCStartMenuPath" -Force -ErrorAction SilentlyContinue }

$MSCStartMenuPath = Join-Path -Path $([system.environment]::GetFolderPath('CommonPrograms')) -ChildPath 'Microsoft System Centre\Configuration Manager'
If (Test-Path -Path "$MSCStartMenuPath\Software Centre.lnk") { Remove-Item -Path "$MSCStartMenuPath\Software Centre.lnk" -Force -ErrorAction SilentlyContinue }
$Files = @(Get-ChildItem -Path $MSCStartMenuPath -Filter '*.lnk' -File -Recurse -ErrorAction SilentlyContinue)
If ($Files.count -eq 0) { Remove-Item -Path "$MSCStartMenuPath" -Force -ErrorAction SilentlyContinue }

$MEMStartMenuPath = Join-Path -Path $([system.environment]::GetFolderPath('CommonPrograms')) -ChildPath 'Microsoft Endpoint Manager\Configuration Manager'
If (Test-Path -Path "$MEMStartMenuPath\Software Center.lnk") { Remove-Item -Path "$MEMStartMenuPath\Software Center.lnk" -Force -ErrorAction SilentlyContinue }
If (Test-Path -Path "$MEMStartMenuPath\Software Centre.lnk") { Remove-Item -Path "$MEMStartMenuPath\Software Centre.lnk" -Force -ErrorAction SilentlyContinue }
$Files = @(Get-ChildItem -Path $MEMStartMenuPath -Filter '*.lnk' -File -Recurse -ErrorAction SilentlyContinue)
If ($Files.count -eq 0) { Remove-Item -Path "$MEMStartMenuPath" -Force -ErrorAction SilentlyContinue }

# Remove ConfigMgr self-signed certificates
Write-LogMessage -Message 'Remove ConfigMgr self-signed certificates'
Get-ChildItem -Path 'cert:LocalMachine\SMS\*' | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path 'HKLM:\SOFTWARE\Microsoft\SystemCertificates\SMS\Certificates\*' -Force -ErrorAction SilentlyContinue

If ($Force -or $ResetWMI) {
  # Remove WMI Namespaces
  Write-LogMessage -Message 'Remove WMI Namespaces'
  Get-WmiObject -Query "SELECT * FROM __Namespace WHERE Name='ccm'" -Namespace root | Remove-WmiObject
  Get-WmiObject -Query "SELECT * FROM __Namespace WHERE Name='sms'" -Namespace root\CIMv2 | Remove-WmiObject
}
If ($Force -or $ResetWUPolicy) {
  # Remove Windows Update Agent policies and rely on GPO or MDM to reapply them
  Write-LogMessage -Message 'Remove Windows Update Agent policy registry keys and rely on GPO or MDM to reapply them'
  Remove-Item -Path HKLM:\Software\Policies\Microsoft\Windows\WindowsUpdate\ -Recurse -Force -ErrorAction SilentlyContinue
  $UpdatePolicy = $true
}
If ($Force -or $ResetMDM) {
  # Reset MDM Authority
  Write-LogMessage -Message 'Remove MDM Authority registry keys'
  Remove-Item -Path 'HKLM:\SOFTWARE\Microsoft\DeviceManageabilityCSP' -Force -Recurse -ErrorAction SilentlyContinue
  $UpdatePolicy = $true
}
If ($Force -or $ResetGPO) {
  # Remove cached machine group policies
  Write-LogMessage -Message 'Remove cached machine group policies'
  Remove-Item "$env:SystemRoot\System32\GroupPolicy\Machine\Registry.pol" -Force -ErrorAction SilentlyContinue
  $UpdatePolicy = $true
}
If ($Force -or $UpdatePolicy) {
  #Update Group Policies
  Start-Process -FilePath "$env:SystemRoot\system32\cmd.exe" -ArgumentList '/C echo N | gpupdate.exe /Target:Computer /Force' -ErrorAction SilentlyContinue -WindowStyle Hidden #-Verb RunAs -Wait
  Start-Sleep -Seconds 3

  #Sync MDM policy (3 methods to chose from)
  #https://oliverkieselbach.com/2020/11/03/triggering-intune-management-extension-ime-sync/
  #$Shell = New-Object -ComObject Shell.Application
  #$Shell.open("intunemanagementextension://syncapp")
  #Restart-Service -Name IntuneManagementExtension -ErrorAction SilentlyContinue
  #https://oofhours.com/2019/09/28/forcing-an-mdm-sync-from-a-windows-10-client/
  Get-ScheduledTask | Where-Object { $_.TaskName -eq 'PushLaunch' } | Start-ScheduledTask
}

# Get final status to determine success
$CCMService = Get-Service -Name ccmexec -ErrorAction SilentlyContinue
If ($CCMService) {
  $ExitCode = 1073 #0x431 ERROR_SERVICE_EXISTS / The specified service already exists.
  Write-LogMessage -Message "Service still exists, completing with failure $ExitCode" -Type Error
  # alter the failure exit code to allow ConfigMgr to retry the execution
  $ExitCode = 999
  # ConfigMgr Execution Failure Retry Error Codes https://home.memftw.com/configmgr-and-failed-program-retry/
  Write-LogMessage -Message "Completing with ConfigMgr recognized failure with retry, exit code $ExitCode" -Type Error
} Else {
  $ExitCode = 0
  Write-LogMessage -Message "Completing with success, exit code $ExitCode"
}
#endregion ########## Main Script ######################################################################################
#region ############# Finalization ########################################################## #BOOKMARK: Script Finalize
Write-LogMessage -Message "==================== Completed Script ====================" -Console
#endregion ########## Finalization #####################################################################################
Exit $ExitCode