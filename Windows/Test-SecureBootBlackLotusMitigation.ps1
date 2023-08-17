#.SYNOPSIS
#   Test-SecureBootBlackLotusMitigation.ps1
#   KB5025885 / CVE-2023-24932 mitigation detection
#   https://support.microsoft.com/en-us/topic/kb5025885-how-to-manage-the-windows-boot-manager-revocations-for-secure-boot-changes-associated-with-cve-2023-24932-41a975df-beb2-40c1-99a3-b3ff139f832d#logerrors5025885
#.NOTE
#   Test if each mitigation is in place after installing patches for KB5025885 / CVE-2023-24932 and activating the mitigations
#
#   For ConfigMgr, each mitigation could be created as a Complicance Item and the two should be deployed as a Compliance Baseline
#   For Intune, the entire script should be used as a custom compliance policy

#Name: Secure Boot KB5025885 SKUSIPolicy
#Description: KB5025885 / CVE-2023-24932 mitigation part 3 of 3 (patch, DBX update, and SKUSIPolicy.p7b update)

# Compliance Item Name: SKUSIPolicy.p7b update
## Discovery
$RegPath = 'registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\SecureBoot'
$SKUSIregName = 'SKUSIPolicy.p7b update'
try {
	$RegValue = Get-ItemProperty -Path $RegPath -Name $SKUSIregName -ErrorAction Stop | Select-Object -ExpandProperty $SKUSIregName 
} catch { $null }
If ($RegValue -as [datetime]) { 
	Write-Output $true
} Else { 
	Write-Output $false
}

## Remediation
$RegPath = 'registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\SecureBoot'
$SKUSIregName = 'SKUSIPolicy.p7b update'
try {
   # This event log entry occurs on each Windows boot event.  It is unlikely it will age/roll out of the event log
   # Event ID 276 will be logged when the boot manager loads the SKUSIPolicy.p7b successfully.
   #  Message: Windows boot manager revocation policy version 0x2000000000002 is applied.
   $SKUSIPolicyUpdate = Get-WinEvent -LogName 'Microsoft-Windows-Kernel-Boot/Operational' -FilterXPath "*[System[Provider[@Name='Microsoft-Windows-Kernel-Boot']][EventID=276]]" -Oldest -MaxEvents 1
   try { 
      # Write a custom registry key indicating that the Event Log entry exists
      [void](New-ItemProperty -Path $RegPath -Name $SKUSIregName -PropertyType String -Value $((Get-Date -Date $SKUSIPolicyUpdate.TimeCreated -Format u).replace(' ','T')) -Force -ErrorAction Stop)
      Write-Output $true
   } catch {
      Write-Output "failed to create $SKUSIregName custom registry key"
      throw $_
   }
} catch {
   Write-Output "$SKUSIregName event log entry not found"
   throw $_
}
# ConfigMgr Compliance Settings reports Compliant if a Remediation script exits without throwing an error.


# Compliance Item Name: Secure Boot DBX update
## Discovery
$RegPath = 'registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\SecureBoot'
$DBXregName = 'Secure Boot DBX update'
try {
	$RegValue = Get-ItemProperty -Path $RegPath -Name $DBXregName -ErrorAction Stop | Select-Object -ExpandProperty $DBXregName 
} catch { $null }
If ($RegValue -as [datetime]) { 
	Write-Output $true
} Else { 
	Write-Output $false
}
## Remediation
$RegPath = 'registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\SecureBoot'
$DBXregName = 'Secure Boot DBX update'
try { 
   # This event log entry occurs when the mitigation is activated, thus it will age/roll out of the event log
   # Event ID 1035 will be logged when the DBX update has been applied to the firmware successfully.
   # Message: Secure Boot DBX update applied successfully
   $DBXupdate = Get-WinEvent -LogName 'System' -FilterXPath "*[System[Provider[@Name='Microsoft-Windows-TPM-WMI']][EventID=1035]]" -Oldest -MaxEvents 1 -ErrorAction Stop
   try { 
      # Write a custom registry key indicating that the Event log entry exists
      [void](New-ItemProperty -Path $RegPath -Name $DBXregName -PropertyType String -Value $((Get-Date -Date $DBXupdate.TimeCreated -Format u).replace(' ','T')) -Force -ErrorAction Stop)
      Write-Output $true
   } catch {
      Write-Output "failed to create $DBXregName custom registry key"
      throw $_
   }
} catch {
   Write-Output "$DBXregName event log entry not found"
   throw $_
}
# ConfigMgr Compliance Settings reports Compliant if a Remediation script exits without throwing an error.


# Intune and/or ConfigMgr compliance only (no remediation) of custom registry keys
<#
$RegPath = 'registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\SecureBoot'
$DBXregName = 'Secure Boot DBX update'
$SKUSIregName = 'SKUSIPolicy.p7b update'
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
