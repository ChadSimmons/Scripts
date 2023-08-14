#.SYNOPSIS
#   Test-SecureBootBlackLotusMitigation.ps1
#   KB5025885 / CVE-2023-24932 mitigation detection
#   https://support.microsoft.com/en-us/topic/kb5025885-how-to-manage-the-windows-boot-manager-revocations-for-secure-boot-changes-associated-with-cve-2023-24932-41a975df-beb2-40c1-99a3-b3ff139f832d#logerrors5025885
#.NOTE
#   Test if each mitigation is in place after installing patches for KB5025885 / CVE-2023-24932 and activating the mitigations
#
#   For ConfigMgr, each mitigation could be created as a Complicance Item and the two should be deployed as a Compliance Baseline
#   For Intune, the entire script should be used as a custom compliance policy

$RegPath = 'registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\SecureBoot'


$DBXregName = 'Secure Boot Dbx update'
$DBXregValue = try { (Get-ItemProperty -Path $RegPath -Name $DBXregName -ErrorAction Stop) | Select-Object -ExpandProperty $DBXregName } catch { $null }
If ([string]::IsNullOrEmpty($DBXregValue)) {
	# This event log entry occurs one time, thus it will age/roll out of the event log
	$DBXupdate = Get-WinEvent -LogName 'System' -FilterXPath "*[System[Provider[@Name='Microsoft-Windows-TPM-WMI']][EventID=1035]]" -Oldest -MaxEvents 1
	# Event ID 1035 will be logged when the DBX update has been applied to the firmware successfully.
	#  Message: Secure Boot Dbx update applied successfully
	If ($DBXupdate) {
		Write-Output "Write a custom registry key indicating that the $DBXregName event log entry occurred"
		Try { New-ItemProperty -Path $RegPath -Name $DBXregName -PropertyType String -Value $(Get-Date -Date $DBXupdate.TimeCreated -Format u) -Force -ErrorAction Stop } catch { throw $_; Exit 3 }
	} Else {
		Write-Output "$DBXregName event log entry not found"
	}
} Else {
	Write-Output "$DBXregName custom registry key exists"
}


$SKUSIregName = 'SKUSIPolicy.p7b update'
$SKUSIregValue = try { (Get-ItemProperty -Path $RegPath -Name $SKUSIregName -ErrorAction Stop) | Select-Object -ExpandProperty $SKUSIregName } catch { $null }
If ([string]::IsNullOrEmpty($SKUSIregValue)) {
	# This event log entry occurs on each Windows boot event.  It is unlikely it will age/roll out of the event log
	$SKUSIPolicyUpdate = Get-WinEvent -LogName 'Microsoft-Windows-Kernel-Boot/Operational' -FilterXPath "*[System[Provider[@Name='Microsoft-Windows-Kernel-Boot']][EventID=276]]" -Oldest -MaxEvents 1
	# Event ID 276 will be logged when the boot manager loads the SKUSIPolicy.p7b successfully.
	#  Message: Windows boot manager revocation policy version 0x2000000000002 is applied.
	If ($SKUSIPolicyUpdate) {
		Write-Output "Write a custom registry key indicating that the $SKUSIregName event log entry occurred"
		Try { New-ItemProperty -Path $RegPath -Name $SKUSIregName -PropertyType String -Value $(Get-Date -Date $SKUSIPolicyUpdate.TimeCreated -Format u) -Force -ErrorAction Stop } catch { throw $_; Exit 4 }
	} Else {
		Write-Output "$SKUSIregName event log entry not found"
	}
} Else {
	Write-Output "$SKUSIregValue custom registry key exists"
}


<#
# for Intune and or ConfigMgr compliance
$DBXregValue = try { (Get-ItemProperty -Path $RegPath -Name $DBXregName -ErrorAction Stop) | Select-Object -ExpandProperty $DBXregName } catch { $null }
$SKUSIregValue = try { (Get-ItemProperty -Path $RegPath -Name $SKUSIregName -ErrorAction Stop) | Select-Object -ExpandProperty $SKUSIregName } catch { $null }
If ($DBXregValue -as [datetime] -and $SKUSIregValue -as [datetime]) {
	# all mitigations detected
	Write-Output $true
	Exit 0
} Else {
	Write-Output $false
	Exit 2
}
#>
