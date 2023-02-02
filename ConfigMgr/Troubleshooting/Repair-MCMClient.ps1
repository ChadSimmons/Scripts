#.Synopsis


#.Notes
<#
Based on
https://learn.microsoft.com/en-us/mem/configmgr/core/clients/manage/client-health-checks
https://www.prajwaldesai.com/repair-sccm-client-agent/
https://forums.prajwaldesai.com/threads/sccm-client-install-failed-with-exit-code-1603.1047/#post-4282
https://www.hashmat00.com/sccm-client-repair-ps-script/
https://github.com/mattbalzan/PowerShell-Scripts/blob/master/SCCM_Client_Tools.ps1
https://www.powershellgallery.com/packages/Fixing_CCMClient/1.3/Content/Fixing_CCMClient.ps1
https://social.technet.microsoft.com/wiki/contents/articles/25696.how-to-uninstall-or-remove-sccm-client.aspx
https://jamesachambers.com/remove-microsoft-sccm-by-force/
https://www.anoopcnair.com/fix-sccm-client-issues-automation/
#>

# Relaunch as an elevated process
If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
	Start-Process powershell.exe '-File', ('"{0}"' -f $MyInvocation.MyCommand.Path) -Verb RunAs
	exit
}

#Get-WmiObject win32_operatingsystem | select csname, @{LABEL='LastBootUpTime';EXPRESSION={$_.ConverttoDateTime($_.lastbootuptime)}}
#Get-WmiObject win32_operatingsystem | select csname, @{LABEL='LastBootUpTime';EXPRESSION={$_.ConverttoDateTime($_.lastbootuptime)}}

Function Start-CCMRepair () {
<# https://www.prajwaldesai.com/repair-sccm-client-agent/
What is CCMRepair.exe?
ccmrepair.exe is an executable that allows you to repair Configuration Manager client agent.

What is the location of CCMRepair?
The ccmrepair file is located in C:\windows\ccm\ folder.

How do I Repair SCCM client agent?
To repair SCCM client agent on a computer, run ccmrepair.exe that is located in C:\windows\ccm\ folder.
#>
}


Function Stop-MCMServices () {
	Get-Process ccmexec -ErrorAction SilentlyContinue|Stop-Process -Force -ErrorAction SilentlyContinue
	Get-Service ccmexec -ErrorAction SilentlyContinue|Stop-Service -Force -ErrorAction SilentlyContinue

}
Function Repair-WMI () {

	Stop-Service -Name Winmgmt -Force -ErrorAction SilentlyContinue

    Start-Process -FilePath "$env:SystemRoot\System32\wbem\WinMgmt.exe" -ArgumentList '/VerifyRepository' -Wait -NoNewWindow
	#if STDIO = 'WMI repository is consistent' then WMI should be OK
	Start-Process -FilePath '$env:SystemRoot\System32\wbem\WinMgmt.exe' -ArgumentList '/SalvageRepository' -Wait -NoNewWindow
	Start-Process -FilePath '$env:SystemRoot\System32\wbem\WinMgmt.exe' -ArgumentList '/VerifyRepository' -Wait -NoNewWindow
	#if STDIO = 'WMI repository is consistent' then WMI should be OK

	Start-Process -FilePath '$env:SystemRoot\System32\wbem\WinMgmt.exe' -ArgumentList '/ResetRepository' -Wait -NoNewWindow
	Start-Process -FilePath '$env:SystemRoot\System32\wbem\WinMgmt.exe' -ArgumentList '/VerifyRepository' -Wait -NoNewWindow
	#if STDIO = 'WMI repository is consistent' then WMI should be OK

	#Repair WMI
	$Path = 'C:\Windows\System32\wbem'
	Stop-Service -Name Winmgmt -Force
	Remove-Item "$Path\repository" -Recurse -Force
	& wmiprvse /regserver
	Start-Service -Name Winmgmt
	Get-ChildItem $Path -Filter *.dll | ForEach-Object { & regsvr32.exe /s $_.FullName } | Out-Null
	Get-ChildItem $Path -Filter *.mof | ForEach-Object { & mofcomp.exe $_.FullName } | Out-Null
	Get-ChildItem $Path -Filter *.mfl | ForEach-Object { & mofcomp.exe $_.FullName } | Out-Null
	& mofcomp.exe 'C:\Program Files\Microsoft Policy Platform\ExtendedStatus.mof' | Out-Null

	Start-Service Winmgmt


Function Repair-WMI { #from ConfigMgrClientHealth.ps1 by Anders Rodland
        $text ='Repairing WMI'
        Write-Output $text

        # Check PATH
        if((! (@(($ENV:PATH).Split(";")) -contains "$env:SystemDrive\WINDOWS\System32\Wbem")) -and (! (@(($ENV:PATH).Split(";")) -contains "%systemroot%\System32\Wbem"))){
            $text = "WMI Folder not in search path!."
            Write-Warning $text
        }
        # Stop WMI
        Stop-Service -Force ccmexec -ErrorAction SilentlyContinue
        Stop-Service -Force winmgmt

        # WMI Binaries
        [String[]]$aWMIBinaries=@("unsecapp.exe","wmiadap.exe","wmiapsrv.exe","wmiprvse.exe","scrcons.exe")
        foreach ($sWMIPath in @(($ENV:SystemRoot+"\System32\wbem"),($ENV:SystemRoot+"\SysWOW64\wbem"))) {
            if(Test-Path -Path $sWMIPath){
                push-Location $sWMIPath
                foreach($sBin in $aWMIBinaries){
                    if(Test-Path -Path $sBin){
                        $oCurrentBin=Get-Item -Path  $sBin
                        & $oCurrentBin.FullName /RegServer
                    }
                    else{
                        # Warning only for System32
                        if($sWMIPath -eq $ENV:SystemRoot+"\System32\wbem"){
                            Write-Warning "File $sBin not found!"
                        }
                    }
                }
                Pop-Location
            }
        }

        # Reregister Managed Objects
        Write-Verbose "Reseting Repository..."
        & ($ENV:SystemRoot+"\system32\wbem\winmgmt.exe") /resetrepository
        & ($ENV:SystemRoot+"\system32\wbem\winmgmt.exe") /salvagerepository
        Start-Service winmgmt
        $text = 'Tagging ConfigMgr client for reinstall'
        Write-Warning $text
    }


}


Function Suspend-BitLocker () {
	            Suspend-BitLocker -MountPoint "C:" -RebootCount 1 -ErrorAction Stop
            Write-Host "computer is going to reboot"
            Restart-Computer -Force
}


Function Repairt-WindowsImageEx {
	#https://jamesachambers.com/remove-microsoft-sccm-by-force/
	Repair-WindowsImage -Online -CheckHealth
	Repair-WindowsImage -Online -ScanHealth
	Repair-WindowsImage -Online -RestoreHealth
	sfc /scannow
}

Function Enable_MPSSVC($computerName, $logPath) {

	Get-Service -ComputerName $ComputerName -Name WinRM |Start-Service
	Write-Host 'going to fix'
	Invoke-Command -ComputerName $ComputerName -ScriptBlock {
		Write-Host 'started fixing'

		$MpssvcregPath = 'HKLM:\SYSTEM\CurrentControlSet\Services\mpssvc'
		$BFEregPath = 'HKLM:\SYSTEM\CurrentControlSet\Services\bfe'

		Try {
			Get-ItemProperty $BFEregPath -ErrorAction Stop
			$regACL = Get-Acl $BFEregPath
			$regRule = New-Object System.Security.AccessControl.RegistryAccessRule('Everyone', 'FullControl', 'ContainerInherit', 'None', 'Allow')


			$regACL.AddAccessRule($regRule)
			$regACL|Set-Acl

			Get-ItemProperty $MpssvcregPath
			$regACL = Get-Acl $MpssvcregPath


			$regACL.AddAccessRule($regRule)
			$regACL|Set-Acl

			Write-Host 'Success!'
		}

		Catch {

			Write-Host "Failed enable MPSVC! on $ComputerName"
			"windows defender firewall is not running on machine $computer"
			$ComputerName|Out-File "$logPath\Repair_failed_List.txt" -Append
		}

		Start-Service -Name mpssvc


	}

}

<#

# ================================================================================================
#This script repair uninstall the SCCM Client, Repair the WMI Repository
# and Reinstall the SCCM Client, it's basic, but work fine !
# Don't forget to download WMIRepair and configure the script (see above)
# PowerShell 3.0 require
# The WMIRepair.exe require .NET Framework 3.5
# ================================================================================================


# ================================================================================================
#
# Parameters - Must match your infrastructure
#
$PathScript = Split-Path -Parent $PSCommandPath # Path of the current script
$LocalSCCMClient = '.\client\ccmsetup.exe' # Path of the Source of SCCM Client (on local computer)
$RemoteSCCMClient = '\\fit-win-sccm-03\Client\ccmsetup.exe' # Path of the Source of SCCM Client (from Server)
$SCCMSiteCode = 'NMI' # SCCM Site Code
$wmiRepair = "$PathScript\wmirepair.exe"
#
# Please put WMIRepair.exe and WMIRepair.exe.config in the same folder of this script
# It can be downloaded from https://sourceforge.net/projects/smsclictr/files/latest/download
# The files are under <ZIP File>\Program Files\Common Files\SMSCliCtr
# The sources was from SCCM Client Center by Roger Zander (Grüezi Roger !)
#
# ================================================================================================

If (Test-Path $LocalSCCMClient -ErrorAction SilentlyContinue) {
	# Uninstall the SCCM Client
	Write-Host 'Removing SCCM Client...'
	Start-Process -FilePath $LocalSCCMClient -ArgumentList '/uninstall' -Wait
}

# clean sccm files
Get-Process -Name CMTrace | Stop-Process -Force -ErrorAction Continue -Verbose
if ((Test-Path 'C:\windows\CCM') -eq 'true') {
	Remove-Item -Path C:\windows\CCM -Recurse -Force -ErrorAction Continue -Verbose
}
if ((Test-Path 'HKLM:SOFTWARE\Microsoft\SMS\') -eq 'true') {
	Remove-Item  'HKLM:SOFTWARE\Microsoft\SMS\' -Recurse -Force -ErrorAction Continue -Verbose
}


# Stop Winmgmt
Write-Host 'Stopping WMI Service...'
Set-Service Winmgmt -StartupType Disabled -ErrorAction SilentlyContinue
Stop-Service Winmgmt -Force -ErrorAction SilentlyContinue

# Sleep 10 for WMI Stop
Write-Host 'Waiting 10 seconds...'
Start-Sleep -Seconds 10

# Remove old backup
If (Test-Path C:\Windows\System32\wbem\repository.old -ErrorAction SilentlyContinue) {
	Write-Host 'Removing old Repository backup...'
	Remove-Item -Path C:\Windows\System32\wbem\repository.old -Recurse -Force -ErrorAction SilentlyContinue
}

# Rename the existing repository directory.
Write-Host 'Renaming the Repository...'
Rename-Item -Path C:\Windows\System32\wbem\repository -NewName 'Repository.old' -Force -ErrorAction SilentlyContinue


# Start WMI Service, this action reconstruct the WMi Repository
Write-Host 'Starting WMI Service...'
Set-Service Winmgmt -StartupType Automatic -ErrorAction SilentlyContinue
Start-Service Winmgmt -ErrorAction SilentlyContinue

# Sleep 10 for WMI Startup
Write-Host 'Waiting 10 seconds...'
Start-Sleep -Seconds 10

# Start other services
Write-Host 'Starting IP Helper Service...'
Start-Service iphlpsvc -ErrorAction SilentlyContinue
Write-Host 'Starting WMI Service...'
Start-Service Winmgmt -ErrorAction SilentlyContinue

# Sleep 1 Minute to allow the WMI Repository to Rebuild
Write-Host 'Waiting 1 Minute for rebuild the Repository...'
Start-Sleep -Seconds 60

# Run WMIRepair.exe
Write-Host 'Starting WMIRepair...'
Start-Process -FilePath $wmiRepair -ArgumentList '/CMD' -Wait

# Clear ccmsetup folder
Write-Host 'Clean local ccmsetup folder...'
Remove-Item -Path C:\Windows\ccmsetup\* -Recurse -ErrorAction SilentlyContinue
# stop cmtrace process
Get-Process -Name CMTrace | Stop-Process -Force -ErrorAction Continue -Verbose
# remove ccm folder
if ((Test-Path 'C:\windows\CCM') -eq 'true') {
	Remove-Item -Path C:\windows\CCM\* -Recurse -Force -ErrorAction Continue -Verbose
}
#remove SCCM SMS registry
if ((Test-Path 'HKLM:SOFTWARE\Microsoft\SMS\') -eq 'true') {
	Remove-Item  'HKLM:SOFTWARE\Microsoft\SMS\' -Recurse -Force -ErrorAction Continue -Verbose
}

# Get the current ccmsetup.exe from the Site Server
Write-Host 'Copy a fresh copy of ccmsetup.exe from Site Server...'
Copy-Item -Path $RemoteSCCMClient -Destination C:\Windows\ccmsetup -ErrorAction SilentlyContinue

# Sleep 10 seconds to allow the WMI Repository to Rebuild
Write-Host 'Waiting 10 seconds for rebuild the Repository...'
Start-Sleep -Seconds 10

# Install the client
Write-Host "Install SCCM Client on Site Code:$SCCMSiteCode..."
Start-Process -FilePath $LocalSCCMClient -Wait

$SCCMInstallTime = Get-Item -Path C:\Windows\ccmsetup\ccmsetup.cab | Select-Object -Property CreationTime
Write-Host "SCCM Client Installed on $SCCMInstallTime"

#>

