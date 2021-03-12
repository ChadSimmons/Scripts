################################################################################
#.SYNOPSIS
#   Get-Uptime.ps1
#   Report the time a local, remote, or list of remote Windows computers have
#      been running since their last restart/reboot/power on
#.DESCRIPTION
#   This script generally requires administrative rights to remotely execute a
#	   WMI get object command
#
#   The entire script could be reduced to the following and still get the critical information
#      Get-WMIObject -Computer $env:ComputerName -Namespace root\CIMv2 -class Win32_OperatingSystem | Select-Object PSComputerName, LocalDateTime, LastBootUpTime, @{Name='UptimeMinutes'; Expression={ [int]([Management.ManagementDateTimeConverter]::ToDateTime($_.LocalDateTime)-[Management.ManagementDateTimeConverter]::ToDateTime($_.LastBootUpTime)).TotalMinutes }}
#.PARAMETER ComputerName
#   comma separated list of computer name(s) to report against
#.EXAMPLE
#   Get-Uptime.ps1
#   Report the up time details of the local computer
#.EXAMPLE
#   Get-Uptime.ps1 -ComputerName $env:ComputerName, RemoteComputer1, RemoteComputer2
#   Report the up time details of the local computer and 2 remote computers
#.NOTES
#   This script is maintained at https://github.com/ChadSimmons/Scripts
#   Additional information about the function or script.
#   ========== Keywords ==========
#   Keywords: reboot restart power on power cycle
#   ========== Change Log History ==========
#   - 2021/03/12 by Chad.Simmons@CatapultSystems.com - Created
#   - 2021/03/12 by Chad@ChadsTech.net - Created
################################################################################
[CmdletBinding()]
param ([string[]]$ComputerName = $env:ComputerName)
Function Get-Uptime {
	[cmdletbinding()]
	Param([Parameter(Mandatory = $true)][string[]]$ComputerName)
	Begin {
		$MyTimeZone = (Get-WmiObject -Computer $env:ComputerName -Namespace 'root\CIMv2' -Class 'Win32_OperatingSystem' -ErrorAction Stop -Property CurrentTimeZone).CurrentTimeZone
		Write-Output "My TimeZone is $MyTimeZone"
	}
	Process {
		$Report = @()
		$ComputerNameCount = $ComputerName.Count; $iCount = 0
		ForEach ($Computer in $ComputerName) {
			$iCount++
			Write-Progress -Activity 'Connecting to remote computers' -Status "[$iCount / $ComputerNameCount] $Computer"
			$Uptime = New-Object -TypeName PSObject -Property $([ordered]@{ ComputerName = $Computer; Status = 'undefined'; UptimeMinutes = $null; UptimeHours = $null; UptimeDays = $null; LocalDateTime = $null; LastBootUpTime = $null; OSInstallDate = $null; CurrentTimeZone = $null; OSName = $null; OSVersion = $null; OSArchitecture = $null; })
			try {
				$WMI = Get-WMIObject -Computer $Computer -Namespace 'root\CIMv2' -Class 'Win32_OperatingSystem' -ErrorAction Stop
				$Uptime.Status = $WMI.Status #'Connected'
				$Uptime.UptimeMinutes = [int]([Management.ManagementDateTimeConverter]::ToDateTime($WMI.LocalDateTime) - [Management.ManagementDateTimeConverter]::ToDateTime($WMI.LastBootUpTime)).TotalMinutes
				Write-Verbose -Message "Computer $Computer `t$($Uptime.UptimeMinutes) uptime minutes"
				$Uptime.UptimeHours = [math]::Round($Uptime.UptimeMinutes / 60, 1)
				$Uptime.UptimeDays = [math]::Round($Uptime.UptimeMinutes / 60 / 24, 1)
				$Uptime.LocalDateTime = [Management.ManagementDateTimeConverter]::ToDateTime($WMI.LocalDateTime)
				$Uptime.LastBootUpTime = [Management.ManagementDateTimeConverter]::ToDateTime($WMI.LastBootUpTime)
				$Uptime.OSInstallDate = [Management.ManagementDateTimeConverter]::ToDateTime($WMI.InstallDate)
				$Uptime.CurrentTimeZone = $WMI.CurrentTimeZone
				$Uptime.OSName = $WMI.Caption
				$Uptime.OSVersion = $WMI.Version
				$Uptime.OSArchitecture = $WMI.OSArchitecture
			} Catch {
				$Uptime.Status = 'Connection Failed'
				Write-Verbose -Message "Computer $Computer `tConnection Failed"
			}
			$Report += $Uptime
		}
	}
	End {
		Return $Report
	}
}
$global:UptimeData = @(Get-Uptime -ComputerName $ComputerName)
If ($UptimeData.count -eq 1) { $UptimeData | Format-List }
ElseIf ($UptimeData.count -gt 1) { $UptimeData | Format-Table * -AutoSize }
Else { Write-Output 'No data returned' }
Write-Host 'Uptime data object is $UptimeData'