################################################################################
#.SYNOPSIS
#	Test-PendingRestart.ps1
#    Gets the pending reboot status on a local or remote computer.
#.DESCRIPTION
#    This function will query multiple components of the local or remote computer to determine if the
#    system is pending a Restart.
#
#    WindowsUpdate = Windows Update / Auto Update (Windows 2003+)
#    CCMClient = SCCM 2012 Clients only (DetermineIfRebootPending method) otherwise $null value
#    CBServicing = Component Based Servicing (Windows 2008+)
#    DomainJoin = Detects a domain join operation (Windows 2003+)
#    ComputerRename = Detects a computer rename operation (Windows 2003+)
#    FileRename = PendingFileRenameOperations (Windows 2003+)
#    PendFileRenVal = PendingFileRenameOperations registry value; used to filter if need be, some Anti-
#                     Virus leverage this key for def/dat removal, giving a false positive PendingRestart
#.EXAMPLE
#    Test-PendingRestart.ps1 -Computer RemoteComputerName
#.EXAMPLE
#	  & Test-PendingRestart.ps1 -Computer $(Get-Content -Path D:\Servers.txt)
#.EXAMPLE
#	  & Test-PendingRestart.ps1 -ComputerList D:\Workstations.txt
#.LINK
#    Component-Based Servicing:
#    http://technet.microsoft.com/en-us/library/cc756291(v=WS.10).aspx
#
#    PendingFileRename/Auto Update:
#    http://support.microsoft.com/kb/2723674
#    http://technet.microsoft.com/en-us/library/cc960241.aspx
#    http://blogs.msdn.com/b/hansr/archive/2006/02/17/patchreboot.aspx
#
#    SCCM 2012/CCM_ClientSDK:
#    http://msdn.microsoft.com/en-us/library/jj902723.aspx
#.NOTES
#	This script is maintained at https://github.com/ChadSimmons/Scripts
#	========== Change Log History ==========
#	- 2017/07/25 by Chad Simmons - Rewrote as an advanced function with logging and progress messages
#	- 2016/01/30 by Chad.Simmons@CatapultSystems.com - updated
#	- 2015/07/27 by Brian Wilhite - updated
#	- 2012/08/29 by Brian Wilhite - bcwihite@live.com - created
#	=== To Do / Proposed Changes ===
#	- TODO: Implement action logging
#	========== Additional References and Reading ==========
#	- Based on Brian Wilhite's Get-PendingReboot.ps1 script published at https://gallery.technet.microsoft.com/Get-PendingReboot-Query-bdb79542
################################################################################

[cmdletbinding()]
param (
	[Parameter()][string[]]$Computer = "$env:ComputerName",
	[Parameter()][string]$ComputerList,
	[string]$ResultsFile, # = 'D:\WorkingFiles\Test-PendingRestart.csv',
	[string]$LogFile, #TODO: Implement action logging
	[switch]$doRestart,
	[int]$RestartDelaySeconds = 300,
	[string]$RestartMessage
)

#region    ######################### Functions #################################
################################################################################
Function Restart-ComputerEx {
	[cmdletbinding()]
	param (
		[Parameter(Mandatory=$true)][string]$ComputerName,
		[Parameter()][ValidateRange(5, 315360000)][int]$RestartDelaySeconds = 300,
		[string]$RestartMessage
	)
	#Write-LogMessage -Message "$ComputerName`: Restarting with a delay of $RestartDelaySeconds seconds"
	#not using PowerShell Restart-Computer because no user interface (GUI) is presented
	Return $(Start-Process -FilePath "$env:WinDir\System32\shutdown.exe" -ArgumentList '/m',"\\$ComputerName",'/i','/r',"/t $RestartDelaySeconds",'/f').ExitCode #/d p|u:xx:yy
}
Function Test-PendingRestartEx {
	[cmdletbinding()]
	param (
		[Parameter()][string[]]$Computer = "$env:ComputerName",
		[string]$ResultsFile,
		[switch]$doRestart,
		[int]$RestartDelaySeconds = 600,
		[string]$RestartMessage
	)

	$ComputerStatus = @()
	$HKLM = [UInt32] "0x80000002"
	$i=0
	ForEach ($ComputerName in $Computer) {
		$i++
		$Progress=@{Id=1; Activity = "Checking for Pending Restart"; Status="[$i of $($Computer.Count)] $ComputerName"; PercentComplete=$($i / $($Computer.count) * 100)}
		Write-Progress @Progress
		$CCMClientSDK = $null
		$RestartStatus = New-Object -TypeName PSObject -Property @{
			Computer=$ComputerName
			Online=$null #$isOnline
			RestartPending=$null #($CompPendRen -or $CBSRestartPend -or $WUAURestartReq -or $SCCM -or $PendFileRename)
			CBServicing=$null #$CBSRestartPend
			WindowsUpdate=$null #$WUAURestartReq
			CCMClient=$null #$SCCM
			DomainJoin=$null
			ComputerRename=$null #$CompPendRen
			FileRename=$null #$PendFileRename
			FileRenameVal=$null
			RestartAction=$null
			Comment=$null
		}

		Write-Progress @Progress -CurrentOperation 'Testing Connection (Ping)'
		If (Test-Connection -ComputerName $ComputerName -Count 1 -Quiet) {
			$RestartStatus.Online = $true
			## Querying WMI for build version
			try {
				#Write-Progress @Progress -CurrentOperation 'Connecting to WMI'
				#$WMI_OS = Get-WmiObject -Class Win32_OperatingSystem -Property BuildNumber,CSName -ComputerName $ComputerName -ErrorAction Stop
				Write-Verbose "$ComputerName`: Connecting to WMI Registry Provider"
				Write-Progress @Progress -CurrentOperation 'Connecting to WMI Registry Provider'
				$WMI_Reg = [WMIClass] "\\$ComputerName\root\default:StdRegProv"

				## If Vista/2008 & Above query the CBS Reg Key
				## not all versions of Windows has this value
				#If ([Int32]$WMI_OS.BuildNumber -ge 6001) {
				Write-Verbose "$ComputerName`: Checking OS Build"
				$OSBuild = $WMI_Reg.GetStringValue($HKLM,"SOFTWARE\Microsoft\Windows NT\CurrentVersion\",'CurrentBuildNumber')
				Write-Verbose "$ComputerName`: OSBuild is $($OSBuild.sValue)"
				$RestartStatus.Comment += "OSBuild=$($OSBuild.sValue);"
				If ([int]$OSBuild.sValue -ge 6001) {
					Write-Progress @Progress -CurrentOperation 'Checking Component Based Servicing'
					try {
						$RegSubKeysCBS = $WMI_Reg.EnumKey($HKLM,"SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\")
						$RestartStatus.CBServicing = $RegSubKeysCBS.sNames -contains "RebootPending"
					} catch {}
				}
				Write-Verbose "$ComputerName`: Checking OS Product"
				try {
					$OSProduct = $WMI_Reg.GetStringValue($HKLM,"SOFTWARE\Microsoft\Windows NT\CurrentVersion\",'ProductName')
					$RestartStatus.Comment += "OSProduct=$($OSProduct.sValue);"
				} catch {}

				## Query WUAU from the registry
				Write-Verbose "$ComputerName`: Checking Windows Update"
				Write-Progress @Progress -CurrentOperation 'Checking Windows Update'
				try {
					$RegWUAURestartReq = $WMI_Reg.EnumKey($HKLM,"SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\")
					$RestartStatus.WindowsUpdate = $RegWUAURestartReq.sNames -contains "RebootRequired"
				} catch {}

				## Query PendingFileRenameOperations from the registry
				Write-Verbose "$ComputerName`: Checking Pending File Rename Operations"
				Write-Progress @Progress -CurrentOperation 'Checking Pending File Rename Operations'
				try {
					$RegSubKeySM = $WMI_Reg.GetMultiStringValue($HKLM,"SYSTEM\CurrentControlSet\Control\Session Manager\","PendingFileRenameOperations")
					## If PendingFileRenameOperations has a value set $RegValuePFRO variable to $true
					If ($RegSubKeySM.sValue) {
						$RestartStatus.FileRename = $true
						$RestartStatus.FileRenameVal = $RegSubKeySM.sValue
					} else {
						$RestartStatus.FileRename = $false
					}
				} catch {}

				## Query JoinDomain key from the registry - These keys are present if pending a Restart from a domain join operation
				Write-Verbose "$ComputerName`: Checking for domain join operation"
				Write-Progress @Progress -CurrentOperation 'Checking for domain join operation'
				try {
					$Netlogon = $WMI_Reg.EnumKey($HKLM,"SYSTEM\CurrentControlSet\Services\Netlogon").sNames
					$RestartStatus.DomainJoin = ($Netlogon -contains 'JoinDomain') -or ($Netlogon -contains 'AvoidSpnSet')
				} catch {}

				## Query ComputerName and ActiveComputerName from the registry
				Write-Verbose "$ComputerName`: Checking for computer rename operation"
				Write-Progress @Progress -CurrentOperation 'Checking for computer rename operation'
				try {
					$regComputerNameActive = $WMI_Reg.GetStringValue($HKLM,"SYSTEM\CurrentControlSet\Control\ComputerName\ActiveComputerName\","ComputerName")
					$regComputerName = $WMI_Reg.GetStringValue($HKLM,"SYSTEM\CurrentControlSet\Control\ComputerName\ComputerName\","ComputerName")
					If ($regComputerNameActive -eq $regComputerName) {
						$RestartStatus.ComputerRename = $false
					} else {
						$RestartStatus.ComputerRename = $true
					}
				} catch {}

				## Determine SCCM 2012 Client Restart Pending Status
				## To avoid nested 'if' statements and unneeded WMI calls to determine if the CCM_ClientUtilities class exist, setting EA = 0
				Try {
					Write-Verbose "$ComputerName`: Checking Microsoft System Center Configuration Manager WMI namespace"
					Write-Progress @Progress -CurrentOperation 'Checking Microsoft System Center Configuration Manager WMI namespace'
					$CCMClientSDK = Invoke-WmiMethod -ComputerName $ComputerName -Namespace 'ROOT\ccm\ClientSDK' -Class 'CCM_ClientUtilities' -Name 'DetermineIfRebootPending' -ErrorAction 'Stop'
				} Catch [System.UnauthorizedAccessException] {
					Write-Verbose "$ComputerName`: Checking Microsoft System Center Configuration Manager service"
					Write-Progress @Progress -CurrentOperation 'Checking Microsoft System Center Configuration Manager service'
					$CcmStatus = Get-Service -Name CcmExec -ComputerName $ComputerName -ErrorAction SilentlyContinue
					If ($CcmStatus.Status -ne 'Running') {
						#Write-Warning "$Computer`: Error - CcmExec service is not running."
						$CCMClientSDK = $null
					}
				} Catch {
					$CCMClientSDK = $null
				}

				If ($CCMClientSDK) {
					If ($CCMClientSDK.ReturnValue -eq 0) {
						If ($CCMClientSDK.IsHardRebootPending -or $CCMClientSDK.RebootPending) {
							$RestartStatus.CCMClient = $true
						} else {
							$RestartStatus.CCMClient = $false
						}
					} else {
						#Write-Warning "Error: DetermineIfRebootPending returned error code $($CCMClientSDK.ReturnValue)"
					}
				}
			} catch {}

			If ($doRestart) {
				Write-Verbose "$ComputerName`: Invoking computer restart"
				$Progress.Activity = "Checking for Pending Restart (and restarting if Pending!!!)"
				Write-Progress @Progress -CurrentOperation 'Restarting computer'
				#Write-LogMessage -Message "$ComputerName`: Attempting computer restart"
				$RestartStatus.RestartAction = 'attempted'
				try {
					$RestartStatus.RestartAction = $(Restart-ComputerEx -ComputerName $ComputerName -RestartDelaySeconds $RestartDelaySeconds -RestartMessage "$RestartMessage").ExitCode
					#Write-LogMessage -Message "$ComputerName`: Restart attempt returned success"
				} catch {
					#Write-LogMessage -Message "$ComputerName`: Restart attempt failed with error code ???"
				}
			}
		} else {
			$RestartStatus.Online = $false
		}
		#TODO: Verify the case of one having a null value which may result in an invalid state
		$RestartStatus.RestartPending=($RestartStatus.CBServicing -or $RestartStatus.CCMClient -or $RestartStatus.DomainJoin -or $RestartStatus.ComputerRename -or $RestartStatus.FileRename -or $RestartStatus.WindowsUpdate)
		Write-Host "$($RestartStatus.Computer) is $($RestartStatus.RestartPending)"
		$ComputerStatus += $RestartStatus
		If ($ResultsFile) {
			$RestartStatus | Add-Member -MemberType NoteProperty -Name 'Timestamp' -Value $(Get-Date -Format 'yyyy/MM/dd hh:mm:ss')
			$RestartStatus | Select-Object Timestamp, Computer, Online, RestartPending, RestartAction, CBServicing, WindowsUpdate, CCMClient, ComputerRename, DomainJoin, FileRename, Comment | Export-Csv -Path "$ResultsFile" -Append -NoTypeInformation
		}
		Remove-Variable RestartStatus
	}
	Return $ComputerStatus
}
################################################################################
#endregion ######################### Functions #################################

#region    ######################### Main Script ###############################
#	Determine if processing a list of computers or a single computer
If ([string]::IsNullOrEmpty($ComputerList)) {
} else {
	If (Test-Path -Path $ComputerList) {
		$Computer = @(Get-Content -Path $ComputerList)
		If ([string]::IsNullOrEmpty($ResultsFile)) {
			$ResultsFile = "$([System.IO.Path]::GetDirectoryName($ComputerList))\$([System.IO.Path]::GetFileNameWithoutExtension($ComputerList)).csv"
			#$ResultsFile = "$LogPath\$([System.IO.Path]::GetFileNameWithoutExtension($ComputerList)).csv"
		}
	}
}

#	Perform tests and action(s)
If ($doRestart) {
	$Results = Test-PendingRestartEx -Computer $Computer -ResultsFile "$ResultsFile" -doRestart $true -RestartDelaySeconds $RestartDelaySeconds -RestartMessage "$RestartMessage"
} else {
	$Results = Test-PendingRestartEx -Computer $Computer -ResultsFile "$ResultsFile"
}

#	Output result table to console
$Results | Select-Object Computer, Online, RestartPending, RestartAction, CBServicing, WindowsUpdate, CCMClient, ComputerRename, DomainJoin, FileRename, FileRenameVal, Comment | Format-Table -AutoSize
If ($ResultsFile) { Write-Host "Results saved to $ResultsFile" }
#endregion ######################### Main Script ###############################
