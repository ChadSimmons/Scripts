#region    ####### ConfigMgr Administrative users #####################################################################>
$SiteCode = 'LAB'
$SiteServer = 'CMPrimary.contoso.com'
$ExportFile = 'C:\Data\Get-MECMAdminConsoleUsers.csv'
Push-Location -Path "$SiteCode`:"
$CMAdminUsers = Get-CMAdministrativeUser | Select-Object LogonName, IsGroup
Pop-Location
$CMAdminUserList = @()
ForEach ($CMAdminUser in $CMAdminUsers) {
	Write-Output $CMAdminUser.LogonName
	If ($CMAdminUser.IsGroup -eq $true) {
		$CMAdminUserIDs = (Get-WmiObject -ComputerName $SiteServer -Namespace "root\SMS\site_$($SiteCode)" -Query "Select UniqueUserName from SMS_R_User where UserGroupName like `"$($CMAdminUser.LogonName.replace('\','\\'))`"").UniqueUserName
	} Else {
		$CMAdminUserIDs = (Get-WmiObject -ComputerName $SiteServer -Namespace "root\SMS\site_$($SiteCode)" -Query "Select * from SMS_R_User where UniqueUserName = `"$($CMAdminUser.LogonName.replace('\','\\'))`"").UniqueUserName
	}
	ForEach ($CMAdminUserID in $CMAdminUserIDs) {
		$CMAdminUserList += @(Get-WmiObject -ComputerName $SiteServer -Namespace "root\SMS\site_$($SiteCode)" -Query "Select * from SMS_R_User where UniqueUserName = `"$($CMAdminUserID.replace('\','\\'))`"" | Select-Object @{N = 'Group'; E = { $CMAdminUser.LogonName } }, UniqueUserName, ResourceID, ResourceType, UserName, Name, displayname, WindowsNTDomain, distinguishedName, FullDomainName, FullUserName, UserPrincipalName, mail, mobile, telephoneNumber, UserGroupName)
	}
}
$CMAdminUserList | Select-Object Group, UniqueUserName, ResourceID, ResourceType, UserName, Name, displayname, WindowsNTDomain, distinguishedName, FullDomainName, FullUserName, UserPrincipalName, mail, mobile, telephoneNumber | Export-Csv -Path "filesystem::$($ExportFile)" -NoTypeInformation
Write-Output "Exported $($CMAdminUserList.Count) users to $ExportFile"
#endregion ####### ConfigMgr Administrative users #####################################################################>
