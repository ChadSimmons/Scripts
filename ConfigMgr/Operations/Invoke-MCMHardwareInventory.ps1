#requires -Version 3.0
################################################################################
#.SYNOPSIS
#	Invoke-SCCMHardwareInventory.ps1
#	Initiate SCCM Hardware Inventory
#.DESCRIPTION
#	This script will initiate an SCCM hardware inventory and return a 1 if it fails to initiate or a 0 if it is a success. The script works by scanning the InventoryAgent. log file for the status of the hardware inventory.
#.PARAMETER Full
#   Force a FULL / Major Inventory instead of Delta
#.PARAMETER Wait
#   Monitor the inventory progress and wait for completion.  Return a valid exit/return/error code on completion.
#.PARAMETER Timeout
#   Time in minutes to monitor the inventory progress and wait before giving up
#.EXAMPLE
#   Invoke-SCCMHardwareInventory.ps1 -Full -Wait
#.LINK
#   SCCM Hardware Inventory with Verification: https://mickitblog.blogspot.com/2017/09/sccm-hardware-inventory-with.html
#.NOTES
#   This script is maintained at https://github.com/ChadSimmons/Scripts
#   Additional information about the function or script.
#   ========== Keywords ==========
#   Keywords: SCCM ConfigMgr Hardware Inventory
#   ========== Change Log History ==========
#   - 2018/11/07 by Chad Simmons - rewrote almost completely
#   - 2018/11/07 by Chad.Simmons@CatapultSystems.com - Ported from Mick Pletcher
#   - 2016/05/20 by Mick Pletcher - created as SCCMActions.ps1
#   === To Do / Proposed Changes ===
#   - TODO: Add Error handling
#   - TODO: Add optional CMTrace logging
#   - TODO: Add optional central file share reporting
#   ========== Additional References and Reading ==========
################################################################################
[CmdletBinding()]
param (
	 [Parameter()][Alias('Force')][switch]$Full,
	 [Parameter()][Alias('Monitor')][switch]$Wait,
	 [Parameter()][Alias('WaitMinutes')][int]$Timeout = 5
)

Function Write-LogMessage ($Message, $Type) {
	#TODO:
}

Function Monitor-HardwareInventoryCycle {
	#.SYNOPSIS
	#	Hardware Inventory Cycle
	#.DESCRIPTION
	#	This function will invoke a hardware inventory cycle and it waits until the cycle is completed.
	#.NOTES
	#  Look at alternatives for reading/parsing CMTrace style logs as the below seems very inefficient
	#	- https://gallery.technet.microsoft.com/scriptcenter/Get-SCCMLogEntry-77494255
	#	- https://www.adamtheautomator.com/reading-configmgr-logs-with-powershell/
	#	- https://stackoverflow.com/questions/17411269/monitor-a-log-file-with-get-content-wait-until-the-end-of-the-day
	#	- Get-Content -Tail ## -Wait  ... note that Wait requires PowerShell 5+ to work correctly
	#	- https://powershell.org/2013/09/powershell-performance-the-operator-and-when-to-avoid-it/
	#	- https://thesurlyadmin.com/2015/06/01/read-text-files-faster-than-get-content/
	[CmdletBinding()]
	param (
		[parameter()][int]$Timeout = 5
	)

	Write-Output 'Monitoring Hardware Inventory Cycle...'
	$Completed = $false
	$StartDateTime = Get-Date
	$LogFileName = Join-Path -Path $env:WinDir -ChildPath 'ccm\logs\InventoryAgent.log' #TODO: get the actual InventoryAgent.log path, don't presume
	Start-Sleep -Seconds 30
	Do {
		Start-Sleep -Seconds 1
		$TimeDifference = New-TimeSpan -Start $StartDateTime -End Get-Date
		$Log = Get-Content -Path $LogFileName -Tail 1
		#Parse Timestamp
		$LogEntryRegEx = ([regex]'<time="(.+)" date="(.+)" component').matches($Log)
		$LogEntryDateTime = Get-Date -Date $($LogEntryRegEx.groups[2].value + ' ' + ($LogEntryRegEx.groups[1].value).split('.')[0])
		Remove-Variable -Name LogEntryRegEx
		#Parse Log Message
		If ($LogEntryDateTime -ge $StartDateTime) {
			[string]$LogEntryText = (([regex]'<\!\[LOG\[(.+)\]LOG\]\!>').matches($Log)).Groups[1].Value
			Switch -Wildcard ($LogEntryText) {
				"*End of message processing*" {
					Write-Verbose -Message "Completed"
					$Status = 0
					$Completed = $true
				}
				"*already in queue. Message ignored.*" {
					Write-Verbose -Message "Ignored"
					$Status = 162 #162 / 0xA2 / ERROR_SIGNAL_PENDING / A signal is already pending
					$Completed = $true
				}
			}
		}
		If ($TimeDifference.Minutes -ge $Timeout) {
			Write-Verbose -Message "Timeout waiting for inventory"
			$Status = 258 #258 / 0x00000102 / WAIT_TIMEOUT / The wait operation timed out.
			$Completed = $true
		}
	} while ($Completed -eq $false)
	Return $Status
 }

Function Invoke-SCCMHardwareInventory {
	[CmdletBinding()]
	param (
		[Parameter()][Alias('Force')][switch]$Full,
		[Parameter()][Alias('Monitor')][switch]$Wait,
		[Parameter()][Alias('Minutes')][int]$Timeout
	)
	$ScheduleID = '{00000000-0000-0000-0000-000000000001}'
	If ($Full) {
		try {
			(Get-WMIObject -Namespace 'root\ccm\invagt' -Class InventoryActionStatus | Where-Object { $_.InventoryActionID -eq $ScheduleID }).Delete()
			Write-LogMessage -Message 'Deleted WMI Class for SCCM Hardware Inventory to force a Full Inventory Scan'
		} catch {
			Write-LogMessage -Message 'Failed deleting WMI Class for SCCM Hardware Inventory to force a Full Inventory Scan' -Type Error
		}
	}
	Invoke-SCCMTriggerSchedule -ScheduleID $ScheduleID
	If ($Wait) {
		$Result = Monitor-HardwareInventoryCycle -Timeout $Timeout
	}
	Return $Result
}

Function Invoke-SCCMTriggerSchedule {
	#.SYNOPSIS
	#	Initiate Configuration Manager Client Scan
	#.PARAMETER ScheduleID
	#	GUID ID of the SCCM action
	#.PARAMETER Name
	#	Name SCCM action
	#.LINK
	#	https://docs.microsoft.com/en-us/sccm/develop/reference/core/clients/client-classes/triggerschedule-method-in-class-sms_client
	[CmdletBinding()]
	param (
		[parameter()][ValidateSet(
			'{00000000-0000-0000-0000-000000000001}',
			'{00000000-0000-0000-0000-000000000002}',
			'{00000000-0000-0000-0000-000000000003}',
			'{00000000-0000-0000-0000-000000000010}',
			'{00000000-0000-0000-0000-000000000021}',
			'{00000000-0000-0000-0000-000000000022}',
			'{00000000-0000-0000-0000-000000000026}',
			'{00000000-0000-0000-0000-000000000027}',
			'{00000000-0000-0000-0000-000000000031}',
			'{00000000-0000-0000-0000-000000000032}',
			'{00000000-0000-0000-0000-000000000108}',
			'{00000000-0000-0000-0000-000000000113}',
			'{00000000-0000-0000-0000-000000000111}',
			'{00000000-0000-0000-0000-000000000121}')][Alias('ActionID')][string]$ScheduleID,
		[Parameter()][Alias('HW')][switch]$Hardware,
		[Parameter()][Alias('SW')][switch]$Software,
		[Parameter()][Alias('DDR')][switch]$DataDiscovery,
		<# TODO: Add remaining https://docs.microsoft.com/en-us/sccm/develop/reference/core/clients/client-classes/triggerschedule-method-in-class-sms_client
		[Parameter()][Alias('File')][switch]$FileCollection,
		[Parameter()][switch]$IDMIF,
		[Parameter()][switch]$ClientMachineAuthentication,
		[Parameter()][Alias('ComputerRequest')][switch]$MachineRequest,
		[Parameter()][Alias('MachineEval','ComputerEvaluation','ComputerEval')][switch]$MachineEvaluation,
		#>
		[Parameter()][string[]]$Name
	)
	$ScheduleIDMatrix  = @{'Hardware' = '{00000000-0000-0000-0000-000000000001}'}
	$ScheduleIDMatrix += @{'Software' = '{00000000-0000-0000-0000-000000000002}'}
	$ScheduleIDMatrix += @{'DataDiscovery' = '{00000000-0000-0000-0000-000000000003}'}
	# TODO: Add remaining https://docs.microsoft.com/en-us/sccm/develop/reference/core/clients/client-classes/triggerschedule-method-in-class-sms_client
	$ScheduleIDs  = @()
	$ScheduleIDs += $ScheduleID
	If ($PSBoundParameters.ContainsKey('Hardware')) { $ScheduleIDs += $ScheduleIDMatrix['Hardware'] }
	If ($PSBoundParameters.ContainsKey('Software')) { $ScheduleIDs += $ScheduleIDMatrix['Software'] }
	If ($PSBoundParameters.ContainsKey('DataDiscovery')) { $ScheduleIDs += $ScheduleIDMatrix['DataDiscovery'] }
	# TODO: Add remaining https://docs.microsoft.com/en-us/sccm/develop/reference/core/clients/client-classes/triggerschedule-method-in-class-sms_client
	ForEach ($ScheduleName in $Name) {
		$ScheduleIDs += $ScheduleIDMatrix[$ScheduleName]
	}

	ForEach ($ActionID in $ScheduleIDs) {
		try {
			([wmiclass]'root\ccm:SMS_Client').TriggerSchedule($ActionID)
			Write-LogMessage -Message "Triggered ConfigMgr Client ScheduleID $ActionID to invoke the client $() cycle"
		} catch { }
			Write-LogMessage -Message "Failed triggering ConfigMgr Client ScheduleID $ActionID to invoke the client $() cycle" -Type Error
	}
 }

$Status = Invoke-SCCMHardwareInventory -Full -Wait -Timeout 5
If ($Status -eq $true) { $Status = 0 }
If ($Status -eq $false) { $Status = -1 }
Exit $Status