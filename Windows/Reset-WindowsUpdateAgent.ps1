#REQUIRES -Version 2
#REQUIRES -RunAsAdministrator
<#
.SYNOPSIS
	Reset-WindowsUpdateAgent.ps1
	Resets the Windows Update Agent and related components
.DESCRIPTION
	This script will completely reset the Windows Update client to DEFAULT SETTINGS.
	It has been tested on Windows 7, 8, 10, and Server 2012 R2. It will configure the services and registry keys related to Windows Update for default settings.
	It will also clean up files related to Windows Update, in addition to BITS related data.
	Because of some limitations of the cmdlets available in PowerShell, this script calls some legacy utilities (sc.exe, netsh.exe, wusa.exe, etc).
.OUTPUTS
	Results are printed to the console and a CMTrace style log $env:SystemRoot\Logs\WindowsUpdateAgentHealth.log
.EXAMPLE
    .\Reset-WindowsUpdateAgent.ps1
.NOTES
	========== Keywords ==========
    Keywords: Windows Update Agent service WUA
    ========== Change Log History ==========
    - 2023/02/01 by Chad.Simmons@Quisitive.com - items marked as done on this date
		- DONE: Added registry.pol deletion
		- DONE: Add CMTrace style logging
		- DONE: Disabled Windows Update Agent reinstall due to KB2937636 age
    - 2017/11/13 by Ryan Nemeth - v1.20 - Fixed environment variables
    - 2016/09/22 by Ryan Nemeth - v1.10 - Fixed bug with call to sc.exe
    - 2015/05/21 by Ryan Nemeth - Created
		- Blog:     http://www.geekyryan.com
		- Twitter:  https://twitter.com/geeky_ryan
		- LinkedIn: https://www.linkedin.com/in/ryan-nemeth-b0b1504b/
		- Github:   https://github.com/rnemeth90
		- TechNet:  https://social.technet.microsoft.com/profile/ryan%20nemeth/

		- https://gist.github.com/desbest/1a15622ae7d0421a735c6e78493510b3

		Originally posted/hosted on TechNet Gallery by Ryan Nemeth (11,966 points / top 0.5%).  Updated 2017/11/13.  Downloaded 420,323 times.
		- https://archive.is/tYKkN (Archive.org alias)
		- http://web.archive.org/web/20210121052944/https://gallery.technet.microsoft.com/Reset-WindowsUpdateps1-e0c5eb78
		- https://archive.is/o/tYKkN/web.archive.org/web/20210121052944/https://gallery.technet.microsoft.com/Reset-WindowsUpdateps1-e0c5eb78/view/Discussions%23content
	=== To Do / Proposed Changes ===
	- TODO: Validate on PowerShell versions 2, 5.1, and 7
	- TODO: see in-line items

	## GitHub and TechNet Comments
	- Question: When I ran the script, antivirus stopped it and showed this message: PowerShell tried to load a malicious resource detected as Heur.BZC.ZFV.Boxter.341.BF113387 and was blocked. Your device is safe.
	- Response: Heur is short for heuristics which means that your antivirus is using heuristics based scanning instead of signature based or behaviour based scanning. This is common with command line scripts, as they can be written on-the-fly, have access to a large scope of intrusive and potentially dangerous features and because they are only used by a starkly small amount of people. Microsoft Smartscreen will only whitelist a software as safe once a certain amount of users have started using it. You could have a batch script designed to delete one text file or one folder in a harmless manner and it would likely still trigger the antivirus.

	  Your antivirus is being proactive due to wishful thinking as it cannot be certain what the batch script exactly does and how safe it is. It cannot be sure that it's certainly found a virus.
      Well anyway I've tested out this script last year and can say that even though the script can execute on Windows 10, it is now outdated and defunct. This script has no effect on Windows 10. But you wouldn't know that unless you're within the rare use case of having a certain issue with Windows Update. A lot of those instructions are copied from here anyway.
      If you're having problems with Windows Update, I recommend these instructions

	  https://support.microsoft.com/en-us/topic/kb5005322-some-devices-cannot-install-new-updates-after-installing-kb5003214-may-25-2021-and-kb5003690-june-21-2021-66edf7cf-5d3c-401f-bd32-49865343144f

	  Try method 2 from this article
	  https://appuals.com/fix-windows-update-error-0x8024402f/

	  Try running the Windows Update troubleshooter
	  https://www.tenforums.com/tutorials/76013-troubleshoot-problems-windows-10-troubleshooters.html

	  Microsoft also has some good tips
	  https://support.microsoft.com/en-gb/windows/troubleshoot-problems-updating-windows-188c2b0f-10a7-d72f-65b8-32d177eb136c

	  If all else fails, try an in-place upgrade. It will keep your programs and files intact so you won't have to worry about anything being deleted. It's not a feature you can get from the Windows 10 DVD or ISO file. It requires an additional download from Microsoft.
	  https://www.tenforums.com/tutorials/16397-repair-install-windows-10-place-upgrade.html

########################################################################################################################>

If ([string]::IsNullOrEmpty($script:LogFile)) { $LogFile = "$env:SystemRoot\Logs\WindowsUpdateAgentHealth.log" }

Function Write-LogMessage {
	#.Synopsis Write a log entry in CMTrace format with almost as little code as possible (i.e. Simplified Edition)
	param ($Message, [ValidateSet('Error', 'Warn', 'Warning', 'Info', 'Information', '1', '2', '3')]$Type = '1', $LogFile = $script:LogFile, [switch]$Console)
	If (-not(Test-Path 'variable:script:LogFile')) { $script:LogFile = $LogFile }
	Switch ($Type) { { @('2', 'Warn', 'Warning') -contains $_ } { $Type = 2 }; { @('3', 'Error') -contains $_ } { $Type = 3 }; Default { $Type = 1 } }
	If ($Console) { Write-Output "$(Get-Date -F 'yyyy/MM/dd HH:mm:ss.fff')`t$(Switch ($Type) { 2 { 'WARNING: '}; 3 { 'ERROR: '}})$Message" }
	try {
		Add-Content -Path "filesystem::$LogFile" -Encoding UTF8 -WhatIf:$false -Confirm:$false -Value "<![LOG[$Message]LOG]!><time=`"$(Get-Date -F HH:mm:ss.fff)+000`" date=`"$(Get-Date -F 'MM-dd-yyyy')`" component=`" `" context=`" `" type=`"$Type`" thread=`"$PID`" file=`"`">" -ErrorAction Stop
	} catch { Write-Warning -Message "Failed writing to log [$LogFile] with message [$Message]" }
}


Write-LogMessage -Message 'Stopping Windows Services related to the Windows Update Agent' -Console
#TODO: monitor and wait for each to stop
Stop-Service -Force -ErrorAction SilentlyContinue -Name BITS
Stop-Service -Force -ErrorAction SilentlyContinue -Name wuauserv
Stop-Service -Force -ErrorAction SilentlyContinue -Name appidsvc
Stop-Service -Force -ErrorAction SilentlyContinue -Name cryptsvc
#TODO: exit with error if not successful

Write-LogMessage -Message 'Resetting Windows Services related to the Windows Update Agent to default security settings' -Console
 sc.exe sdset bits "D:(A;;CCLCSWRPWPDTLOCRRC;;;SY)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;BA)(A;;CCLCSWLOCRRC;;;AU)(A;;CCLCSWRPWPDTLOCRRC;;;PU)"
#sc.exe sdset bits "D:(A; ; CCLCSWLOCRRC; ; ; AU)(A; ; CCDCLCSWRPWPDTLOCRSDRCWDWO; ; ; BA)(A; ; CCDCLCSWRPWPDTLCRSDRCWDWO; ; ; SO)(A; ; CCLCSWRPWPDTLOCRRC; ; ; SY)S:(AU; FA; CCDCLCSWRPWPDTLOCRSDRCWDWO; ; WD)"
#sc.exe sdset wuauserv "D:(A; ; CCLCSWLOCRRC; ; ; AU)(A; ; CCDCLCSWRPWPDTLOCRSDRCWDWO; ; ; BA)(A; ; CCDCLCSWRPWPDTLCRSDRCWDWO; ; ; SO)(A; ; CCLCSWRPWPDTLOCRRC; ; ; SY)S:(AU; FA; CCDCLCSWRPWPDTLOCRSDRCWDWO; ; WD)"
 sc.exe sdset wuauserv "D:(A;;CCLCSWRPWPDTLOCRRC;;;SY)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;BA)(A;;CCLCSWLOCRRC;;;AU)(A;;CCLCSWRPWPDTLOCRRC;;;PU)"
#sc.exe sdset cryptsvc "D:(A; ; CCLCSWLOCRRC; ; ; AU)(A; ; CCDCLCSWRPWPDTLOCRSDRCWDWO; ; ; BA)(A; ; CCDCLCSWRPWPDTLCRSDRCWDWO; ; ; SO)(A; ; CCLCSWRPWPDTLOCRRC; ; ; SY)S:(AU; FA; CCDCLCSWRPWPDTLOCRSDRCWDWO; ; WD)"
#sc.exe sdset trustedinstaller "D:(A; ; CCLCSWLOCRRC; ; ; AU)(A; ; CCDCLCSWRPWPDTLOCRSDRCWDWO; ; ; BA)(A; ; CCDCLCSWRPWPDTLCRSDRCWDWO; ; ; SO)(A; ; CCLCSWRPWPDTLOCRRC; ; ; SY)S:(AU; FA; CCDCLCSWRPWPDTLOCRSDRCWDWO; ; WD)"

Write-LogMessage -Message 'Resetting Windows Services related to the Windows Update Agent to default startup settings' -Console
sc.exe config wuauserv start= auto
sc.exe config bits start= delayed-auto
sc.exe config cryptsvc start= auto
sc.exe config TrustedInstaller start= demand
sc.exe config DcomLaunch start= auto


Write-LogMessage -Message 'Deleting old files and folders...' -Console
Write-LogMessage -Message "Removing [$env:allusersprofile\Application Data\Microsoft\Network\Downloader\qmgr*.dat]"
Remove-Item -Force -ErrorAction SilentlyContinue -Path "$env:allusersprofile\Application Data\Microsoft\Network\Downloader\qmgr*.dat"

# Delete Windows Update Agent downloads
Write-LogMessage -Message "Removing [$env:SystemRoot\SoftwareDistribution\download]"
Remove-Item -Force -ErrorAction SilentlyContinue -Recurse -Path "$($env:SystemRoot)\SoftwareDistribution\download\*"

# Rename SoftwareDistribution folder
Write-LogMessage -Message "Removing [$env:SystemRoot\SoftwareDistribution.bak]"
Remove-Item -Force -ErrorAction SilentlyContinue -Path $env:SystemRoot\SoftwareDistribution.bak -Recurse
Write-LogMessage -Message "Resetting file and folder attributes for [$env:SystemRoot\SoftwareDistribution]"
& $env:windir\system32\attrib.exe -r -s -h /s /d $env:SystemRoot\SoftwareDistribution
Write-LogMessage -Message "Renaming [$env:SystemRoot\SoftwareDistribution] to [.bak]"
Rename-Item -Force -ErrorAction SilentlyContinue -Path "$($env:SystemRoot)\SoftwareDistribution" -NewName SoftwareDistribution.bak

# Rename Catroot2 folder
Write-LogMessage -Message "Removing [$env:SystemRoot\System32\Catroot2.bak]"
Remove-Item -Force -ErrorAction SilentlyContinue -Path $env:SystemRoot\System32\Catroot2.bak -Recurse
Write-LogMessage -Message "Resetting file and folder attributes for [$env:SystemRoot\System32\Catroot2]"
& $env:windir\system32\attrib.exe -r -s -h /s /d $env:SystemRoot\System32\Catroot2
Write-LogMessage -Message "Renaming [$env:SystemRoot\System32\Catroot2] to [.bak]"
Rename-Item -Force -ErrorAction SilentlyContinue -Path $env:SystemRoot\System32\Catroot2 -NewName Catroot2.bak

If ([System.Environment]::OSVersion.Version.Major -lt 10) {
	Write-LogMessage -Message "Renaming [$env:SystemRoot\WindowsUpdate.log] to [WindowsUpdate.$(Get-Date -Format 'yyyyMMdd').log]"
	Rename-Item -Force -ErrorAction SilentlyContinue -Path "$env:SystemRoot\WindowsUpdate.log" -Destination "WindowsUpdate.$(Get-Date -Format 'yyyyMMdd').log"
	Remove-Item -Force -ErrorAction SilentlyContinue -Path "$env:SystemRoot\WindowsUpdate.log" #this should not exist after the rename
}


#From Repair-UpdateClient.ps1 by Manuel Gil
Write-LogMessage -Message "Renaming [$env:SystemRoot\WinSxS\pending.xml] to [pending.$(Get-Date -Format 'yyyyMMdd').xml]"
Rename-Item -Force -ErrorAction SilentlyContinue -Path "$env:SystemRoot\WinSxS\pending.xml" -NewName "pending.$(Get-Date -Format 'yyyyMMdd').xml"
Remove-Item -Force -ErrorAction SilentlyContinue -Path $env:SystemRoot\WinSxS\pending.xml #this should not exist after the rename


#TODO: from another community solution
#Write-LogMessage -Message "Renaming [$env:SystemRoot\spupdsvc.exe] to [spupdsvc.bak]"
#Remove-Item -Force -ErrorAction SilentlyContinue -Path $env:SystemRoot\system32\spupdsvc.bak
#Rename-Item -Force -ErrorAction SilentlyContinue -Path $env:SystemRoot\spupdsvc.exe -Destination spupdsvc.bak


Write-LogMessage -Message 'Removing WSUS client settings' -Console
#TODO: Backup existing registry for potential troubleshooting
Remove-ItemProperty -Force -ErrorAction SilentlyContinue -Path 'registry::HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate' -Name AccountDomainSid
Remove-ItemProperty -Force -ErrorAction SilentlyContinue -Path 'registry::HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate' -Name PingID
Remove-ItemProperty -Force -ErrorAction SilentlyContinue -Path 'registry::HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate' -Name SusClientId
Remove-ItemProperty -Force -ErrorAction SilentlyContinue -Path 'registry::HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate' -Name SusClientIDValidation


Write-LogMessage -Message 'Resetting the WinSock' -Console
#NOTE: WINSOCK RESET may require a computer restart/reboot to complete
netsh winsock reset
netsh winhttp reset proxy


Write-LogMessage -Message 'Delete all BITS jobs' -Console
#needs PowerShell 3.0+ Get-BitsTransfer -AllUsers | Remove-BitsTransfer
BitsAdmin.exe /Reset /AllUsers


Write-LogMessage -Message 'Resetting Active Directory Group Policy (deleting registry.pol)' -Console
Write-LogMessage -Message "Renaming [$env:SystemRoot\System32\GroupPolicy\Machine\Registry.pol] to [Registry.$(Get-Date -Format 'yyyyMMdd').pol]"
Rename-Item -Force -ErrorAction SilentlyContinue -Path "$env:SystemRoot\System32\GroupPolicy\Machine\Registry.pol" -NewName "Registry.$(Get-Date -Format 'yyyyMMdd').pol"
Remove-Item -Force -ErrorAction SilentlyContinue -Path "$env:SystemRoot\System32\GroupPolicy\Machine\Registry.pol" #this should not exist after the rename


Write-LogMessage -Message 'Registering DLLs for Windows Update Agent' -Console
$Files = 'atl.dll,urlmon.dll,mshtml.dll,shdocvw.dll,browseui.dll,jscript.dll,vbscript.dll,scrrun.dll,msxml.dll,msxml3.dll,msxml6.dll,actxprxy.dll,softpub.dll,wintrust.dll,dssenh.dll,rsaenh.dll,gpkcsp.dll,sccbase.dll,slbcsp.dll,cryptdlg.dll,oleaut32.dll,ole32.dll,shell32.dll,initpki.dll,wuapi.dll,wuaueng.dll,wuaueng1.dll,wucltui.dll,wups.dll,wups2.dll,wuweb.dll,qmgr.dll,qmgrprxy.dll,wucltux.dll,muweb.dll,wuwebv.dll' -split ','
ForEach ($File in $Files) { & $env:SystemRoot\system32\regsvr32.exe "/s $env:windir\system32\$File" }


Write-LogMessage -Message 'Starting Windows Services related to the Windows Update Agent' -Console
Start-Service -ErrorAction SilentlyContinue -Name cryptsvc
Start-Service -ErrorAction SilentlyContinue -Name appidsvc
Start-Service -ErrorAction SilentlyContinue -Name BITS
Start-Service -ErrorAction SilentlyContinue -Name DcomLaunch
Start-Service -ErrorAction Stop -Name wuauserv #TODO: exit with error if not successful

Write-LogMessage -Message 'Updating Active Directory Group Policy' -Console
GPUpdate.exe /force
#TODO: force Windows MDM / Intune policy update


Write-LogMessage -Message 'Force Windows Update detection/scan/discovery' -Console
wuauclt.exe /resetauthorization /detectnow
#wuauclt.exe /FakeReboot
#wuauclt.exe /resetauthorization
#wuauclt.exe /detectnow
#wuauclt.exe /reportnow
#wuauclt.exe /TestWSUSServer
#wuauclt.exe /downloadnowfast

Write-LogMessage -Message 'trigger ConfigMgr Software Updates Assignments Evaluation Cycle' -Console
#TODO: if ConfigMgr client is installed, restart service and run update cycle
([wmiclass]'root\ccm:SMS_Client').TriggerSchedule('{00000000-0000-0000-0000-000000000108}')


Write-LogMessage -Message 'Remediation finished.  Restart computer complete' -Console -Type Warn
exit 3010
