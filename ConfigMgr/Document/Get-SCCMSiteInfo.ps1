$SiteCode = 'LAB'
Push-Location "$SiteCode`:"
$SaveDir = "$env:USERPROFILE\Documents\Export-CMSite"
$ExportDelimiter = "`t"
$ObjectCounts = @{}
If (!(Test-Path $SaveDir)) { New-Item -Path $SaveDir -ItemType Directory }

Get-CMSite | Select-Object * | Export-Csv -Path "$SaveDir\Get-CMSite.csv" -Delimiter $ExportDelimiter -NoTypeInformation
$SiteServer = (Get-CMSite | Where-Object { $_.SiteCode -eq $SiteCode }).ServerName

#needs work to ExpandProperty for multiple items
Get-CMAccount | Export-Csv -Path "$SaveDir\Get-CMAccount.csv" -Delimiter $ExportDelimiter -NoTypeInformation
Get-CMActiveDirectoryForest | Export-Csv -Path "$SaveDir\Get-CMActiveDirectoryForest.csv" -Delimiter $ExportDelimiter -NoTypeInformation
Get-CMActiveDirectorySite | Export-Csv -Path "$SaveDir\Get-CMActiveDirectorySite.csv" -Delimiter $ExportDelimiter -NoTypeInformation
Get-CMAdministrativeUser | Export-Csv -Path "$SaveDir\Get-CMAdministrativeUser.csv" -Delimiter $ExportDelimiter -NoTypeInformation
Get-CMAlertSubscription | Export-Csv -Path "$SaveDir\Get-CMAlertSubscription.csv" -Delimiter $ExportDelimiter -NoTypeInformation
Get-CMAntimalwarePolicy | Out-file -FilePath "$SaveDir\Get-CMAntimalwarePolicy.txt"
Get-CMApplication | Select-Object CI_ID, PackageID, NumberOfDeploymentTypes, DateLastModified, IsDeployed, IsLatest, Manufacturer, LocalizedDisplayName, SoftwareVersion | Export-Csv -Path "$SaveDir\Get-CMApplication.csv" -Delimiter $ExportDelimiter -NoTypeInformation
Get-CMApplicationCatalogWebServicePoint | Export-Csv -Path "$SaveDir\Get-CMApplicationCatalogWebServicePoint.csv" -Delimiter $ExportDelimiter -NoTypeInformation
Get-CMApplicationCatalogWebsitePoint | Export-Csv -Path "$SaveDir\Get-CMApplicationCatalogWebsitePoint.csv" -Delimiter $ExportDelimiter -NoTypeInformation
Get-CMAppVVirtualEnvironment | Export-Csv -Path "$SaveDir\Get-CMAppVVirtualEnvironment.csv" -Delimiter $ExportDelimiter -NoTypeInformation
#Get-CMAssetIntelligenceCatalogItem
#Get-CMAssetIntelligenceSynchronizationPoint
#Get-CMAutomaticAmtProvisioningStatus
#Get-CMBaseline
##Get-CMBaselineSummarizationSchedule
#Get-CMBaselineXMLDefinition
Get-CMBootImage | Out-file -FilePath "$SaveDir\Get-CMBootImage.txt"
Get-CMBoundary | Export-Csv -Path "$SaveDir\Get-CMBoundary.csv" -Delimiter $ExportDelimiter -NoTypeInformation
Get-CMBoundaryGroup | Export-Csv -Path "$SaveDir\Get-CMBoundaryGroup.csv" -Delimiter $ExportDelimiter -NoTypeInformation
Get-CMClientPushInstallation -SiteSystemServerName $SiteServer | Export-Csv -Path "$SaveDir\Get-CMClientPushInstallation.csv" -Delimiter $ExportDelimiter -NoTypeInformation
Get-CMClientSetting | Export-Csv -Path "$SaveDir\Get-CMClientSetting.csv" -Delimiter $ExportDelimiter -NoTypeInformation
Get-CMClientSetting | Out-file -FilePath "$SaveDir\Get-CMClientSetting.txt"
Get-CMClientStatusSetting | Export-Csv -Path "$SaveDir\Get-CMClientStatusSetting.csv" -Delimiter $ExportDelimiter -NoTypeInformation
Get-CMClientStatusUpdateSchedule | Export-Csv -Path "$SaveDir\Get-CMClientStatusUpdateSchedule.csv" -Delimiter $ExportDelimiter -NoTypeInformation
Get-CMCloudDistributionPoint -Name * | Export-Csv -Path "$SaveDir\Get-CMCloudDistributionPoint.csv" -Delimiter $ExportDelimiter -NoTypeInformation
Get-CMComputerAssociation | Export-Csv -Path "$SaveDir\Get-CMComputerAssociation.csv" -Delimiter $ExportDelimiter -NoTypeInformation
Get-CMConfigurationItem | Select-Object CI_ID, DateLastModified, InUse, IsLatest, IsSuperseded, LocalizedDisplayName, LocalizedDescription | Export-Csv -Path "$SaveDir\Get-CMConfigurationItem.csv" -Delimiter $ExportDelimiter -NoTypeInformation
##Get-CMDatabaseProperty -SiteCode $SiteCode
#ForEach ($CMChildSite in (Get-CMSite | Where-Object { $_.SiteCode -ne $SiteCode })) {
#    Get-CMDatabaseReplicationLinkProperty -ParentSiteCode $SiteCode -ChildSiteCode $(($CMChildSite).SiteCode) | Select-Object $SiteCode, $(($CMChildSite).SiteCode), DviewForHINV, DviewForSINV, DviewForStatusMessages, Scheduling, Degrated, Failed, 'Send History Summarize Interval'
#}
#Get-CMDatabaseReplicationStatus

$cmObject = Get-CMDeployment
$ObjectCounts['CMDeployment'] = ($cmObject | Measure-Object).Count
$cmObject | Select-Object ApplicationName, AssignmentID, CI_ID, CollectionID, CollectionName, CreationTime, DeploymentID, DeploymentIntent, DeploymentTime, DesiredConfigType, EnforcementDeadline, FeatureType, ModificationTime, NumberErrors, NumberInProgress, NumberOther, NumberSuccess, NumberTargeted, NumberUnknown, ObjectTypeID, PackageID, PolicyModelID, ProgramName, SoftwareName, SummarizationTime, UniqueIdentifier | Export-Csv -Path "$SaveDir\Get-CMDeployment.csv" -Delimiter $ExportDelimiter -NoTypeInformation

##Get-CMDeploymentPackage
##Get-CMDeploymentStatus
##Get-CMDeploymentType

$cmObject = Get-CMDevice
$ObjectCounts['CMDevice'] = ($cmObject | Measure-Object).Count
$cmObject | Select-Object * | Export-Csv -Path "$SaveDir\Get-CMDevice.csv" -Delimiter $ExportDelimiter -NoTypeInformation
#TODO Select only valuable columns

$cmObject = Get-CMDeviceCollection | Where-Object { $_.IsBuiltin -eq $false}
$ObjectCounts['CMDeviceCollection'] = ($cmObject | Measure-Object).Count
$cmObject | Select-Object CollectionID, CollectionType, CollectionVariablesCount, Comment, LastChangeTime, LimitToCollectionID, LimitToCollectionName, LocalMemberCount, MemberCount, Name, PowerConfigsCount, RefreshType, ServiceWindowsCount | Export-Csv -Path "$SaveDir\Get-CMDeviceCollection.csv" -Delimiter $ExportDelimiter -NoTypeInformation
##Get-CMDeviceCollectionDirectMembershipRule
##Get-CMDeviceCollectionExcludeMembershipRule
##Get-CMDeviceCollectionIncludeMembershipRule
##Get-CMDeviceCollectionQueryMembershipRule
##Get-CMDeviceCollectionVariable -Collection
Get-CMDiscoveryMethod | Select-Object ComponentName, FileType, Flag, ItemName, ITemType, Name, SiteCode | Export-Csv -Path "$SaveDir\Get-CMDiscoveryMethod.csv" -Delimiter $ExportDelimiter -NoTypeInformation
$cmObject = Get-CMDistributionPoint
$ObjectCounts['CMDistributionPoint'] = ($cmObject | Measure-Object).Count
$cmObject | Select-Object NetworkOSPath, RoleName, SiteCode, sslState, Type | Export-Csv -Path "$SaveDir\Get-CMDistributionPoint.csv" -Delimiter $ExportDelimiter -NoTypeInformation

$cmObject = Get-CMDistributionPointGroup
$ObjectCounts['CMDistributionPointGroup'] = ($cmObject | Measure-Object).Count
$cmObject | Select-Object CollectionCount, ContentCount, ContentInSync, Description, GroupID, HasMember, HasRelationship, MemberCount, ModifiedOn, Name, OutofSyncContentCount, SourceSite | Export-Csv -Path "$SaveDir\Get-CMDistributionPointGroup.csv" -Delimiter $ExportDelimiter -NoTypeInformation

$cmObject = Get-CMDriver
$ObjectCounts['CMDriver'] = ($cmObject | Measure-Object).Count
$cmObject | Select-Object * | Export-Csv -Path "$SaveDir\Get-CMDriver.csv" -Delimiter $ExportDelimiter -NoTypeInformation

$cmObject = Get-CMDriverPackage
$ObjectCounts['CMDriverPackage'] = ($cmObject | Measure-Object).Count
$cmObject | Select-Object * | Export-Csv -Path "$SaveDir\Get-CMDriverPackage.csv" -Delimiter $ExportDelimiter -NoTypeInformation

Get-CMEmailNotificationComponent -SiteCode $SiteCode | Select-Object ComponentName, Flag, ItemType, Name, SiteCode | Export-Csv -Path "$SaveDir\Get-CMEmailNotificationComponent.csv" -Delimiter $ExportDelimiter -NoTypeInformation

Get-CMEndpointProtectionPoint -SiteCode $SiteCode | Select-Object * | Export-Csv -Path "$SaveDir\Get-CMEndpointProtectionPoint.csv" -Delimiter $ExportDelimiter -NoTypeInformation
#Get-CMEndpointProtectionSummarizationSchedule
#Get-CMEnrollmentPoint
#Get-CMEnrollmentProxyPoint
#Get-CMExchangeServer
#Get-CMFallbackStatusPoint -SiteCode $SiteCode

$cmObject = Get-CMFileReplicationRoute -SiteCode $SiteCode
$ObjectCounts['CMFileReplicationRoute'] = ($cmObject | Measure-Object).Count
$cmObject | Select-Object AddressPriorityOrder, AddressType, DesSiteCode, DesSiteName, DestinationType, FileType, ItemName, ItemType, RateLimitingSchedule, SiteCode, SiteName, UnlimitedRateForAll | Export-Csv -Path "$SaveDir\Get-CMFileReplicationRoute.csv" -Delimiter $ExportDelimiter -NoTypeInformation

$cmObject = Get-CMGlobalCondition | Where-Object { $_.IsUserDefined -eq $true }
$ObjectCounts['CMGlobalCondition'] = ($cmObject | Measure-Object).Count
$cmObject | Select-Object * | Select-Object * | Export-Csv -Path "$SaveDir\Get-CMGlobalCondition.csv" -Delimiter $ExportDelimiter -NoTypeInformation

##Get-CMHardwareRequirement

$cmObject = Get-CMIPSubnet
$ObjectCounts['CMIPSubnet'] = ($cmObject | Measure-Object).Count
$cmObject | Select-Object ADSubnetDescription, ADSubnetLocation, ADSubnetName, LastDiscoveryTime | Export-Csv -Path "$SaveDir\Get-CMIPSubnet.csv" -Delimiter $ExportDelimiter -NoTypeInformation

$cmObject = Get-CMManagementPoint
$ObjectCounts['CMManagementPoint'] = ($cmObject | Measure-Object).Count
$cmObject | Select-Object RoleName, RoleCount, NALType, NetworkOSPath, SiteCode, sslState, Type | Export-Csv -Path "$SaveDir\Get-CMManagementPoint.csv" -Delimiter $ExportDelimiter -NoTypeInformation

$cmObject = Get-CMManagementPointComponent -SiteCode $SiteCode
$ObjectCounts['CMManagementPointComponent'] = ($cmObject | Measure-Object).Count
$cmObject | Select-Object * | Export-Csv -Path "$SaveDir\Get-CMManagementPointComponent.csv" -Delimiter $ExportDelimiter -NoTypeInformation

$cmObject = Get-CMSiteDefinition -SiteCode $SiteCode
$ObjectCounts['CMSiteDefinition'] = ($cmObject | Measure-Object).Count
$cmObject | Select-Object * | Export-Csv -Path "$SaveDir\Get-CMSiteDefinition.csv" -Delimiter $ExportDelimiter -NoTypeInformation
$cmObject | Select-Object * | Out-File -FilePath "$SaveDir\Get-CMSiteDefinition.txt"


$cmObject = Get-CMOperatingSystemImage
$ObjectCounts['CMOperatingSystemImage'] = ($cmObject | Measure-Object).Count
$cmObject | Select-Object * | Export-Csv -Path "$SaveDir\Get-CMOperatingSystemImage.csv" -Delimiter $ExportDelimiter -NoTypeInformation

#Get-CMOperatingSystemImageUpdateSchedule

$cmObject = Get-CMOperatingSystemInstaller
$ObjectCounts['CMOperatingSystemInstaller'] = ($cmObject | Measure-Object).Count
$cmObject | Select-Object * | Export-Csv -Path "$SaveDir\Get-CMOperatingSystemInstaller.csv" -Delimiter $ExportDelimiter -NoTypeInformation

#Get-CMOutOfBandManagementComponent
#Get-CMOutOfBandServicePoint

$cmObject = Get-CMPackage
$ObjectCounts['CMPackage'] = ($cmObject | Measure-Object).Count
$cmObject | Select-Object ActionInProgress, Description, Language, LastRefreshTime, Manufacturer, MIFFileName, MIFPublisher, MIFVersion, Name, NumOfPrograms, PackageID, PackageType, PkgFlags, PkgSourcePath, Priority, RefreshSchedule, SecuredScopeNames, ShareName, SourceDate, SourceSite, SourceVersion, Version | Export-Csv -Path "$SaveDir\Get-CMPackage.csv" -Delimiter $ExportDelimiter -NoTypeInformation

$cmObject = Get-CMProgram
$ObjectCounts['CMProgram'] = ($cmObject | Measure-Object).Count
$cmObject | Select-Object ActionInProgress, CommandLine, Comment, DependentProgram, Description, DiskSpaceReq, DriveLetter, Duration, MSIProductID, PackageID, PackageName, PackageVersion, ProgramFlags, ProgramName | Export-Csv -Path "$SaveDir\Get-CMProgram.csv" -Delimiter $ExportDelimiter -NoTypeInformation

##Get-CMQueryResultMaximum

$cmObject = Get-CMReportingServicePoint
$ObjectCounts['CMReportingServicePoint'] = ($cmObject | Measure-Object).Count
$cmObject | Select-Object RoleName, SiteCode, sslState, Type, NetworkOSPath, NALType, FileType | Export-Csv -Path "$SaveDir\Get-CMReportingServicePoint.csv" -Delimiter $ExportDelimiter -NoTypeInformation

$cmObject = Get-CMSecurityRole
$ObjectCounts['CMSecurityRole'] = ($cmObject | Measure-Object).Count
$cmObject | Select-Object IsBuiltIn, LastModifiedDate, NumberofAdmins, RoleID, RoleName, SourceSite, RoleDescription | Export-Csv -Path "$SaveDir\Get-CMSecurityRole.csv" -Delimiter $ExportDelimiter -NoTypeInformation

$cmObject = Get-CMSecurityScope
$ObjectCounts['CMSecurityScope'] = ($cmObject | Measure-Object).Count
$cmObject | Select-Object IsBuiltIn, LastModifiedDate, NumberofAdmins, NumberOfObjects, SourceSite, CategoryName, CategoryID, CategoryDescription | Export-Csv -Path "$SaveDir\Get-CMSecurityScope.csv" -Delimiter $ExportDelimiter -NoTypeInformation

#Get-CMSiteInstallStatus
Get-CMSiteMaintenanceTask -SiteCode $SiteCode | Select-Object TaskName, ItemName, ItemType, SiteCode, Enabled, TaskType, BeginTime, DaysOfWeek, DeleteOlderThan, DeviceName, FileType, LatestBeginTime, NumRefreshDays | Export-Csv -Path "$SaveDir\Get-CMSiteMaintenanceTask.csv" -Delimiter $ExportDelimiter -NoTypeInformation
##Get-CMSiteStatusMessage

$cmObject = Get-CMSoftwareDistributionComponent -SiteCode $SiteCode
$ObjectCounts['CMSoftwareDistributionComponent'] = ($cmObject | Measure-Object).Count
$cmObject | Select-Object * | Export-Csv -Path "$SaveDir\Get-CMSoftwareDistributionComponent.csv" -Delimiter $ExportDelimiter -NoTypeInformation

##Get-CMSoftwareInventory

$cmObjectType = 'SoftwareMeteringRule'
$cmObject = Get-CMSoftwareMeteringRule | Where-Object { $_.RuleID -gt 100 -or $_.Enabled -eq $true}
$ObjectCounts[$cmObjectType] = ($cmObject | Measure-Object).Count
$cmObject | Select-Object ApplyToChildSites, Comment, Enabled, FileName, FileVersion, LanguageID, LastUpdateTime, OriginalFileName, ProductName, RuleID | Export-Csv -Path "$SaveDir\Get-CM$($cmObjectType).csv" -Delimiter $ExportDelimiter -NoTypeInformation
$cmObject | Select-Object * | Out-File -FilePath "$SaveDir\Get-CM$($cmObjectType).txt"

Function Export-CMObjectInfo {
    #TODO: Add proper error handling, logging, verbs, etc. etc.
	param (
		$CMObjects, $ObjectType, $AttributeList
	)
	$ObjectCounts[$ObjectType] = ($CMObjects | Measure-Object).Count
	$CMObjects | Select-Object * | Out-File -FilePath "$SaveDir\Get-CM$($ObjectType).txt"
	$CMObjects | Select-Object $AttributeList | Export-Csv -Path "$SaveDir\Get-CM$($ObjectType).csv" -Delimiter $ExportDelimiter -NoTypeInformation
}

$CMObjects = Get-CMSoftwareMeteringSetting
Export-CMObjectInfo -CMObjects $CMObjects -ObjectType 'SoftwareMeteringSetting' -AttributeList @('ClientComponentName', 'FileType', 'Flags', 'ItemName', 'ItemType', 'SiteCode')

#may timout $CMObjects = Get-CMSoftwareUpdate
#may timout Export-CMObjectInfo -CMObjects $CMObjects -ObjectType 'SoftwareUpdate' #-AttributeList @('ClientComponentName', 'FileType', 'Flags', 'ItemName', 'ItemType', 'SiteCode')

$CMObjects = Get-CMSoftwareUpdateAutoDeploymentRule
Export-CMObjectInfo -CMObjects $CMObjects -ObjectType 'SoftwareUpdateAutoDeploymentRule' -AttributeList @('AutoDeploymentEnabled', 'CollectionID', 'Name', 'Description', 'LastRunTime', 'LastErrorCode', 'Schedule', 'UpdateRuleXML', 'AutoDeploymentProperties', 'DeploymentTemplate')

$CMObjects = Get-CMSoftwareUpdateBasedClientInstallation
Export-CMObjectInfo -CMObjects $CMObjects -ObjectType 'SoftwareUpdateBasedClientInstallation' -AttributeList @('ComponentName', 'FileType', 'Flag', 'ItemType', 'Name', 'SiteCode')



$cmObject = Get-CMSoftwareUpdateDeploymentPackage
$ObjectCounts['CMSoftwareUpdateDeploymentPackage'] = ($cmObject | Measure-Object).Count
$cmObject | Select-Object Description, LastRefreshTime, Name, PackageID, PkgFlags, PkgSourcePath, SecuredScopeNames, SourceDate | Export-Csv -Path "$SaveDir\Get-CMSoftwareUpdateDeploymentPackage.csv" -Delimiter $ExportDelimiter -NoTypeInformation

$cmObject = Get-CMSoftwareUpdateGroup
$ObjectCounts['CMSoftwareUpdateGroup'] = ($cmObject | Measure-Object).Count
$cmObject | Select-Object CI_ID, CIType_ID, CreatedBy, DateCreated, DateLastModified, IsDeployed, IsEnabled, LocalizedDisplayName, LocalizedDescription, NumberofCollectionsDeployed, SecuredScopeNames | Export-Csv -Path "$SaveDir\Get-CMSoftwareUpdateGroup.csv" -Delimiter $ExportDelimiter -NoTypeInformation

$cmObject = Get-CMSoftwareUpdatePoint
$ObjectCounts['CMSoftwareUpdatePoint'] = ($cmObject | Measure-Object).Count
$cmObject | Select-Object RoleName, sslState, SiteCode, Type, NetworkOSPath | Export-Csv -Path "$SaveDir\Get-CMSoftwareUpdatePoint.csv" -Delimiter $ExportDelimiter -NoTypeInformation

$cmObject = Get-CMSoftwareUpdatePointComponent -SiteCode $SiteCode
$ObjectCounts['CMSoftwareUpdatePointComponent'] = ($cmObject | Measure-Object).Count
$cmObject | Select-Object ComponentName, FileType, Flag, ItemType, Name, SiteCode | Export-Csv -Path "$SaveDir\Get-CMSoftwareUpdatePointComponent.csv" -Delimiter $ExportDelimiter -NoTypeInformation

##Get-CMSoftwareUpdateSummarizationSchedule
##Get-CMStateMigrationPoint

$cmObject = Get-CMStatusFilterRule -SiteCode $SiteCode
$ObjectCounts['CMStatusFilterRule'] = ($cmObject | Measure-Object).Count
$cmObject | Select-Object FileType, ItemType, PropertyListName, SiteCode, Values | Out-file -FilePath "$SaveDir\Get-CMStatusFilterRule.txt"

$cmObject = Get-CMStatusMessageQuery # | Where-Object { $_.QueryID -notlike 'SMS*' }
$ObjectCounts['CMStatusMessageQuery'] = ($cmObject | Measure-Object).Count
$cmObject | Select-Object QueryID, LimitToCollectionID, Name, Comments, Expression | Out-file -FilePath "$SaveDir\Get-CMStatusMessageQuery.txt"

#Get-CMStatusReportingComponent
## Get-CMStatusSummarizer
##Get-CMSystemHealthValidationPoint
##Get-CMSystemHealthValidatorPointComponent

#Get-CMTaskSequence
#Get-CMUser

$cmObject = Get-CMUserCollection | Where-Object { $_.IsBuiltIn -eq $false }
$ObjectCounts['CMUserCollection'] = ($cmObject | Measure-Object).Count
$cmObject | Select-Object CollectionID, CollectionType, CollectionVariablesCount, Comment, IncludeExcludeCollectionsCount, LastchangeTime, LimitToCollectionID, LimitToCollectionName, LocalMemberCount, MemberCount, Name, PowerConfigsCount, RefreshType, RefreshSchedule, ServiceWindowsCount | Export-Csv -Path "$SaveDir\Get-CMUserCollection.csv" -Delimiter $ExportDelimiter -NoTypeInformation

#Get-CMUserCollectionDirectMembershipRule
#Get-CMUserCollectionExcludeMembershipRule
#Get-CMUserCollectionIncludeMembershipRule
#Get-CMUserCollectionQueryMembershipRule
#Get-CMUserDataAndProfileConfigurationItem
#Get-CMUserDataAndProfileConfigurationItemXmlDefinition
#Get-CMUserDeviceAffinity
##Get-CMUserDeviceAffinityRequest
#Get-CMWindowsFirewallPolicy

#See Export-SCCMObject.ps1 which incorporates...
#Export-CMAntimalwarePolicy
#Export-CMApplication
#Export-CMBaseline
#Export-CMConfigurationItem
#Export-CMCollection
#Export-CMDriverPackage
#Export-CMPackage
#Export-CMSecurityRole
#Export-CMTaskSequence


#region ===== CmdLet testing =============================================
<#
$cmObject = Get-CMWindowsFirewallPolicy
$ObjectCounts['cmObject'] = ($cmObject | Measure-Object).Count
clear; $cmObject | Select-Object * -Last 2
$ObjectCounts['cmObject']
$cmObject | Select-Object CollectionID, CollectionType, CollectionVariablesCount, Comment, IncludeExcludeCollectionsCount, LastChangeTime, LimitToCollectionID, LimitToCollectionName, LocalMemberCount, MemberCount, Name, PowerConfigsCount, RefreshType, RefreshSchedule, ServiceWindowsCount
 | Export-Csv -Path "$SaveDir\Get-CMobject.csv" -Delimiter $ExportDelimiter -NoTypeInformation
 | Out-file -FilePath "$SaveDir\Get-CMobject.txt"
$cmObject | Get-Member
$cmObject | Where-Object { $_.PackageID -notlike "MC0*" } | Select-Object -First 5
#>
#endregion ===== CmdLet testing  =============================================



<#
Get-CMAntimalwarePolicy | ForEach { Export-CMAntimalwarePolicy -ID $_.UniqueID -ExportFilePath "$SaveDir\CMAntimalwarePolicy.$($_.Name).object" }

Get-CMAntimalwarePolicy | ForEach {
    write-host $_.UniqueID
    #Export-CMAntimalwarePolicy -ID $_.UniqueID -ExportFilePath "$SaveDir\CMAntimalwarePolicy.$($_.Name).object"
    Export-CMAntimalwarePolicy -InputObject $_ -Path "$SaveDir\CMAntimalwarePolicy.$($_.Name).xml"
}
$CM_AP = Get-CMAntimalwarePolicy
Export-CMAntimalwarePolicy -Name "$CM_AP.Name" -ExportFilePath "$SaveDir\CMAntimalwarePolicy.$($CM_AP.Name).xml"
$error[0].
$CM_AP.Name
Get-CMAntimalwarePolicy | Select-Object *
#>


#$ObjectCounts | Select-Object Keys, Values | Export-Csv -Path "$SaveDir\CMObjectCounts.csv" -Delimiter $ExportDelimiter -NoTypeInformation
$ObjectCounts | Out-file -FilePath "$SaveDir\CMObjectCounts.txt"

Function Compress-Files ($ArchiveFile, $SourceFolder) {
	Add-Type -Assembly System.IO.Compression.FileSystem
	$CompressionLevel = [System.IO.Compression.CompressionLevel]::Optimal
	[System.IO.Compression.ZipFile]::CreateFromDirectory($SourceFolder, $ArchiveFile, $CompressionLevel, $false)
}

Pop-Location
Get-Item -Path "$SaveDir.zip" | Select-Object *

If ((Test-path "$SaveDir.zip") -and (Get-Item -Path "$SaveDir.zip").PSIsContainer -eq $false) { Remove-Item "$SaveDir.zip" }
Compress-Files -ArchiveFile "$SaveDir.zip" -SourceFolder $SaveDir
