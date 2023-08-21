#.Synopsis
#   Export-MCMCollectionMemberInfo.ps1
#.Notes
#   2023/08/21 by Chad.Simmons

$SiteCode = 'LAB'
$SiteServer = 'ConfigMgrPri.contoso.com'
$ExportPath = "\\$SiteServer\Logs\Collection Info"



Function Write-LogMessage {
	#.Synopsis Write a log entry in CMTrace format with almost as little code as possible (i.e. Simplified Edition)
	param ($Message, [ValidateSet('Error', 'Warn', 'Warning', 'Info', 'Information', '1', '2', '3')]$Type = '1', $LogFile = $script:LogFile, [switch]$Console)
	If ([string]::IsNullOrEmpty($LogFile)) { $LogFile = "$env:SystemRoot\Logs\ScriptCMTrace.log" }
	If (-not(Test-Path 'variable:script:LogFile')) { $script:LogFile = $LogFile }
	Switch ($Type) { { @('2', 'Warn', 'Warning') -contains $_ } { $Type = 2 }; { @('3', 'Error') -contains $_ } { $Type = 3 }; Default { $Type = 1 } }
	If ($Console) { Write-Output "$(Get-Date -F 'yyyy/MM/dd HH:mm:ss.fff')`t$(Switch ($Type) { 2 { 'WARNING: '}; 3 { 'ERROR: '}})$Message" }
	try {
		Add-Content -Path "filesystem::$LogFile" -Encoding UTF8 -WhatIf:$false -Confirm:$false -Value "<![LOG[$Message]LOG]!><time=`"$(Get-Date -F HH:mm:ss.fff)+000`" date=`"$(Get-Date -F 'MM-dd-yyyy')`" component=`" `" context=`" `" type=`"$Type`" thread=`"$PID`" file=`"`">" -ErrorAction Stop
	} catch { Write-Warning -Message "Failed writing to log [$LogFile] with message [$Message]" }
}

Function Export-MCMCollectionMemberCounts ($NameFilter, $ExportFile) {
	Write-LogMessage -Message "Exporting membership counts for collections [$NameFilter]"
	Set-Location "$SiteCode`:"
	$Colls = Get-CMDeviceCollection -Name "$NameFilter"
	Set-Location -Path 'C:'
	$Coll = $Colls | Select-Object -First 1
	Write-LogMessage -Message "$($Coll.MemberCount) members exist in collection [$($Coll.Name)]"
	$Colls | Select-Object @{N='ReportTime'; E={$(Get-Date -Format $DateFormat -Date $script:dtNow)}}, MemberCount, @{N='LastRefreshTime'; E={$(Get-Date -Format $DateFormat -Date $_.LastRefreshTime)}}, @{N='LastMemberChangeTime'; E={$(Get-Date -Format $DateFormat -Date $_.LastMemberChangeTime)}}, Name | Export-Csv -Path "$ExportFile" -Append -NoTypeInformation
}

Function Export-MCMCollectionMembers ($NameFilter, $ExportFile) {
	Write-LogMessage -Message "Exporting membership for collections [$NameFilter]"
	Set-Location "$SiteCode`:"
	$Colls = Get-CMDeviceCollection -Name "$NameFilter"
	ForEach ($Coll in $Colls) {
		Write-LogMessage -Message "$($Coll.MemberCount) members exist in collection [$($Coll.Name)]"
		Get-CMCollectionMember -CollectionName $Coll.Name | Select-Object @{N='ReportTime'; E={$(Get-Date -Format $DateFormat -Date $script:dtNow)}},@{N='CollectionName'; E={$CollectionName}}, Name, ResourceId, SMSID, SiteCode, ADSiteName, BoundaryGroups, ClientVerion, CNAccessMP, CNIsOnInternet, CNLastOnlineTime, CNLastOfflineTime, DeviceOS, DeviceOSBuild, Domain, IsClient, IsActive, LastMPServerName, MACAddress, LastActiveTime, LastLogonUser, CurrentLogonUser, PrimaryUser, UserName | Export-CSV -Path "filesystem::$ExportFile" -NoTypeInformation -Append
	}
}
$LogPath = $ExportPath
$script:Logfile = $(Join-Path -Path $LogPath -ChildPath 'Export-MCM_CollectionInfo.log')
$script:dtNow = Get-Date
$script:DateFormat = 'yyyy/MM/dd HH:mm:ss'

Write-LogMessage -Message '========================= Initializing ========================='
If (-not(Test-Path -Path $ExportPath -PathType Container)) { New-Item -ItemType Directory -Path $ExportPath -Force -ErrorAction Stop }
Write-LogMessage -Message "ExportPath is [$ExportPath]"

Write-LogMessage -Message 'Importing ConfigMgr PowerShell module'
Import-Module ($Env:SMS_ADMIN_UI_PATH.Substring(0, $Env:SMS_ADMIN_UI_PATH.Length - 5) + '\ConfigurationManager.psd1')
New-PSDrive -Name $SiteCode -PSProvider cmsite -Root $SiteServer -ErrorAction SilentlyContinue



$CollectionName = 'Windows 10 Professional'
Export-MCMCollectionMemberCounts -NameFilter $CollectionName -ExportFile "$ExportPath\ConfigMgr Collection Count History - $CollectionName.csv"
Export-MCMCollectionMembers      -NameFilter $CollectionName -ExportFile "$ExportPath\ConfigMgr Collection Member History - $CollectionName.csv"

Write-LogMessage -Message '========================= Complete ========================='
