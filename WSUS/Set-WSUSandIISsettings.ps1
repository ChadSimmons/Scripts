#.Synopsis
#   Set-WSUSandIISsettings.ps1
#   Configure WSUS and IIS for new requirements and recommendations
#.Description
#   This script should be executed AFTER WSUS is installed.
#   Install patches/updates required for WSUS
#   Service WSUS
#   Apply IIS configurations
#.Link
#      https://blogs.technet.microsoft.com/wsus/2016/05/05/the-long-term-fix-for-kb3148812-issues
#      https://technet.microsoft.com/en-us/library/mt589500.aspx#bkmk_ScaleSieSystems
#      http://www.mnscug.org/blogs/brian-mason/361-how-to-melt-a-sup
#.Notes
#   This script is maintained at https://github.com/ChadSimmons/Scripts/WSUS/blob/master/Set-WSUSandIISsettings.ps1
#   === Change Log / History ===
#   2017/01/05 Chad.Simmons@CatapultSystems.com - minor syntax changes
#   2016/12/01 Chad.Simmons@CatapultSystems.com - Created
#   2016/12/01 Chad@ChadsTech.net - Created
#   === To Do / Proposed Changes ===
#   TODO: Address hotfixes for servers other than Windows Server 2012 R2.  Updates for older versions are different.  Updates for Windows Server 2016 are not needed.
#   TODO: add Windows Application Event and custom CMTrace logging
#   === Additional Reading ===
#   Guidance on how to properly maintain WSUS.
#   - The complete guide to Microsoft WSUS and Configuration Manager SUP maintenance https://blogs.technet.microsoft.com/configurationmgr/2016/01/26/the-complete-guide-to-microsoft-wsus-and-configuration-manager-sup-maintenance/
#   - Software update maintenance in System Center 2012 Configuration Manager https://support.microsoft.com/en-us/kb/3090526
#   - Maintaining WSUS like a boss http://deploymentresearch.com/Research/Post/536/Maintaining-WSUS-Like-a-Boss
#   - SQL Indexing details are covered in another section
#
#region Parameters and variable initialization
#
[CmdletBinding()]
Param(
	[Parameter()][int]$IISMemoryMultiplier=4,
	[Parameter()][int]$MaxMBps = 25, #set to 0 for unlimited / do not configure
	[Parameter()][ValidateScript({[IO.Directory]::Exists($_)})][System.IO.DirectoryInfo]$DownloadPath = "$env:Temp"
)
#region    ========== Debug code
<#
$IISMemoryMultiplier=4
$MaxMBps=25
$DownloadPath = "$env:Temp"
#>
#endregion ========== Debug code

#create WebClient object for downloading files
#
$wc = New-Object System.Net.WebClient
$wc.Proxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials
#
#endregion

#region Download and Install required Updates
#
#verify the OS is Windows Server 2012 R2
If ((Get-WmiObject -Namespace 'root\CIMv2' -Class 'Win32_OperatingSystem').Caption -notlike 'Microsoft Windows Server 2012 R2*') {
    Write-Error -Message 'This script is written for Windows Server 2012 R2 only!'
    Exit -1
}

If (((Get-Hotfix -Id KB3095113).InstalledOn) -is [datetime] -eq $false) {
    Write-Output "Download and install update KB3095113 and hotfix KB3095113"  #2 UPDATES?
    #start-process "$env:ProgramFiles\Internet Explorer\iexplore.exe" -ArgumentList 'https://catalog.update.microsoft.com/v7/site/Search.aspx?q=KB3095113'
    $wc.DownloadFile('http://download.windowsupdate.com/c/msdownload/update/software/htfx/2015/11/windows8.1-kb3095113-x64_0d1737be1c2936a9179f971d03c1074fd4cf762d.msu',"$DownloadPath\windows8.1-kb3095113-x64.msu")
    Start-Process -FilePath "$env:WinDir\system32\wusa.exe" -ArgumentList "$DownloadPath\windows8.1-kb3095113-x64.msu",'/quiet','/norestart',"/log:`"$env:WinDir\Logs\KB3095113.log`"" -Wait -Verb RunAs
    $wc.DownloadFile('http://download.windowsupdate.com/d/msdownload/update/software/updt/2016/03/windows8.1-kb3095113-v2-x64_7187effdf44f577741b3ee6d37e769464c2362fe.msu',"$DownloadPath\windows8.1-kb3095113-v2-x64.msu")
    Start-Process -FilePath "$env:WinDir\system32\wusa.exe" -ArgumentList "$DownloadPath\windows8.1-kb3095113-v2-x64.msu",'/quiet','/norestart',"/log:`"$env:WinDir\Logs\KB3095113v2.log`"" -Wait -Verb RunAs
    Write-Output -Message 'Waiting for KB3095113 to be installed'
    Do { Start-Sleep -Seconds 15; Write-Host '.' -NoNewline
    } Until (((Get-Hotfix -Id KB3095113).InstalledOn) -is [datetime] -eq $true)
}

If (((Get-Hotfix -Id KB3159706).InstalledOn) -is [datetime] -eq $false) {
    Write-Output "Download and install hotfix KB3159706"
    #start-process "$env:ProgramFiles\Internet Explorer\iexplore.exe" -ArgumentList 'https://catalog.update.microsoft.com/v7/site/Search.aspx?q=KB3159706'
    $wc.DownloadFile('http://download.windowsupdate.com/d/msdownload/update/software/updt/2016/05/windows8.1-kb3159706-x64_034b30c6c261d4e76b8c6f8fe3cc9fa5fa4e977b.msu',"$DownloadPath\windows8.1-kb3159706-x64.msu")
    Start-Process -FilePath "$env:WinDir\system32\wusa.exe" -ArgumentList "`"$DownloadPath\windows8.1-kb3159706-x64.msu`"",'/quiet','/norestart',"/log:`"$env:WinDir\Logs\KB3159706.log`"" -Wait -Verb RunAs
    Write-Output -Message 'Waiting for KB3159706 to be installed'
    Do { Start-Sleep -Seconds 15; Write-Host '.' -NoNewline
    } Until (((Get-Hotfix -Id KB3159706).InstalledOn) -is [datetime] -eq $true)
}

If (((Get-Hotfix -Id KB2938066).InstalledOn) -is [datetime] -eq $false) {
    Write-Output "Download and install hotfix KB2938066"
    start-process "$env:ProgramFiles\Internet Explorer\iexplore.exe" -ArgumentList 'https://catalog.update.microsoft.com/v7/site/Search.aspx?q=KB2938066'
    #$wc.DownloadFile('http://download.windowsupdate.com/d/msdownload/update/software/updt/2016/05/windows8.1-kb3159706-x64_034b30c6c261d4e76b8c6f8fe3cc9fa5fa4e977b.msu',"$DownloadPath\windows8.1-kb3159706-x64.msu")
    Start-Process -FilePath "$env:WinDir\system32\wusa.exe" -ArgumentList "`"$DownloadPath\windows8.1-KB2938066-x64.msu`"",'/quiet','/norestart',"/log:`"$env:WinDir\Logs\KB2938066.log`"" -Wait -Verb RunAs
    Write-Output -Message 'Waiting for KB2938066 to be installed'
    Do { Start-Sleep -Seconds 15; Write-Host '.' -NoNewline
    } Until (((Get-Hotfix -Id KB2938066).InstalledOn) -is [datetime] -eq $true)
}

#
#endregion

#region Install additional IIS features
#
Add-WindowsFeature -Name NET-WCF-HTTP-Activation45 -IncludeAllSubFeature -ErrorAction Stop
#
#end region

#region Configure IIS
#
Import-Module WebAdministration
If ($MaxMBPs -gt 0) {
	Set-ItemProperty -Path 'IIS:\Sites\WSUS Administration' -name limits.maxBandwidth ($MaxMBps*1024*1024) #default value of maxBandwidth is 4294967295 (4GB)
}
Set-ItemProperty -Path 'IIS:\AppPools\WsusPool' -Name queueLength -Value 2000 #default is 1000
Set-WebConfiguration "$("/system.applicationHost/applicationPools/add[@name='WsusPool']")/recycling/periodicRestart/@privateMemory" -Value ($IISMemoryMultiplier*1843200) #default is 1843200 (1.75GB)
If ((Get-WebBinding -Name 'WSUS Administration' -Protocol HTTPS).sslFlags -eq 1) {
    Write-Warning 'WSUS Administration site is using IIS.  see KB for additional steps.'
    Start-process "$env:ProgramFiles\Internet Explorer\iexplore.exe" -ArgumentList 'https://support.microsoft.com/en-us/kb/3159706'
    Start-Process -FilePath 'takeown.exe' -ArgumentList '/f',"$Env:ProgramFiles\Update Services\WebServices\ClientWebService\Web.config",'/a' -Wait -Verb RunAs
    Start-Process -FilePath 'icacls.exe' -ArgumentList "$Env:ProgramFiles\Update Services\WebServices\ClientWebService\Web.config",'/grant','administrators:f' -Wait -Verb RunAs
}
#Confirm settings
If ($MaxMBps -gt 0) {
	If ((Get-ItemProperty -Path 'IIS:\Sites\WSUS Administration' -name limits.maxBandwidth).Value -ne ($MaxMBps*1024*1024)) {
		Write-Warning -Message 'WSUS MaxBandwidth value is not as expected.'
	}
}
If ((Get-ItemProperty -Path 'IIS:\AppPools\WsusPool' -Name queueLength).Value -ne 2000) {
    Write-Warning -Message 'WSUS app pool value is not as expected.'
}
If ((Get-WebConfiguration "$("/system.applicationHost/applicationPools/add[@name='WsusPool']")/recycling/periodicRestart/@privateMemory").Value -ne ($IISMemoryMultiplier*1843200)) {
    Write-Warning -Message 'WSUS memory value is not as expected.'
}
#
#endregion

#region Perform WSUS servicing
#
Start-Process -FilePath "$env:ProgramFiles\Update Services\Tools\wsusutil.exe" -ArgumentList 'postinstall','/servicing' -Wait -Verb RunAs -ErrorAction Stop
#
#endregion

#region Perform WSUS servicing
#
Start-Process -FilePath "$env:ProgramFiles\Update Services\Tools\wsusutil.exe" -ArgumentList 'postinstall','/servicing' -Wait -Verb RunAs -ErrorAction Stop
#
#endregion

Restart-Computer -Confirm
