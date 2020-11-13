################################################################################
#.SYNOPSIS
#   Rename-MECMSoftwareUpdateGroupDeployments.ps1
#   Rename ConfigMgr Software Update Group and its Deployments created by an ADR to <ADR Name> YYYY-MM - <Collection Name>
#.PARAMETER SiteCode
#   Specifies 3 character ConfigMgr Site Code
#.PARAMETER SiteServer
#   Specifies NetBIOS or FQDN of ConfigMgr Site Server (SMS Provider / Primary Site Server)
#.PARAMETER YYYYMM
#   Specifies Year and Month in YYYY-MM format such as '2021-09'.  Defaults to the current year and month
#.PARAMETER ADRName
#   Specifies Automatic Deployment Rule Name
#.EXAMPLE
#   Rename-MECMSoftwareUpdateGroupDeployments.ps1 -SiteCode LAB -SiteServer ConfigMgrPrimary.contoso.com -YYYYMM '2020-11' -ADRName 'Microsoft Monthly Updates'
#.EXAMPLE
#   Rename-MECMSoftwareUpdateGroupDeployments.ps1 -SiteCode LAB -SiteServer ConfigMgrPrimary.contoso.com -ADRName 'Microsoft Monthly Updates'
#.NOTES
#   Additional information about the function or script.
#   ========== Keywords ==========
#   Keywords: ConfigMgr SCCM MECM MEMCM Patch
#   ========== Change Log History ==========
#   - 2020/11/12 by Chad.Simmons@CatapultSystems.com - Created
#   - 2020/11/12 by Chad@ChadsTech.net - Created
#   === To Do / Proposed Changes ===
#   #TODO: support WhatIf
#	#TODO: add logging
#   #TODO: add error handling
################################################################################
[cmdletbinding()]
param (
	[Parameter(Mandatory = $true, HelpMessage = 'ConfigMgr Site Code')][ValidateLength(3, 3)][string]$SiteCode,
	[Parameter(Mandatory = $true, HelpMessage = 'ConfigMgr Site Server (SMS Provider / Primary Site Server)')][ValidateLength(3, 255)][string]$SiteServer,
	[Parameter(Mandatory = $false, HelpMessage = 'Year and Month in YYYY-MM format')][string]$YYYYMM = $(Get-Date -Format 'yyyy-MM'),
	[Parameter(Mandatory = $true, HelpMessage = 'Automatic Deployment Rule Name')][string]$ADRName
)
<#
	$SiteCode = 'LAB'
	$SiteServer = 'ConfigMgrPrimary.contoso.com'
	$YYYYMM = '2020-11'
	$ADRName = 'Microsoft Monthly Updates'
#>

$ADRDeploymentNames = "$ADRName_%_$YYYYMM-%" #template name
$SUGName = "$ADRName $YYYYMM"

Write-Host "Getting Software Update Group..."
$SUGID = (Get-WmiObject -Computer $SiteServer -Namespace "root\SMS\site_$($SiteCode)" -Class SMS_AuthorizationList -Filter "LocalizedDisplayName ='$SUGName'").CI_ID
#$SUG = Get-CMSoftwareUpdateGroup -Name "$ADRName $(Get-Date -Date $YYYYMM -format 'yyyy-MM')-%"

Write-Host "Renaming Software Update Group"
If ($SUG) { Set-CMSoftwareUpdateGroup -InputObject $SUG -NewName "$SUGName" -Description "$ADRName $(Get-Date -Date $YYYYMM -Format 'MMMM yyyy')" }

Write-Host "Getting Software Update Deployments"
#$SUGdeployments = @(Get-WmiObject -Computer $SiteServer -Namespace "root\SMS\site_$($SiteCode)" -Class SMS_UpdateGroupAssignment -Filter "AssignmentType=5 and AssignmentName like '$ADRDeploymentNames'")
$SUGdeployments = @(Get-WmiObject -Computer $SiteServer -Namespace "root\SMS\site_$($SiteCode)" -Class SMS_UpdateGroupAssignment -Filter "AssignmentType=5 and AssignedUpdateGroup = $SUGID")
$SUGdeployments | Select-Object AssignmentUniqueID, TargetCollectionID, AssignedUpdateGroup, AssignmentName | Format-Table -AutoSize
$SUGdeployments.Count

Write-Host "Rename Software Update Group Deployments"
#$SUGdeployment = $SUGdeployments | Select -First 1
ForEach ($SUGdeployment in $SUGdeployments) {
	$CollectionName = (Get-WmiObject -Computer $SiteServer -Namespace "root\SMS\site_$($SiteCode)" -Class SMS_Collection -Filter "CollectionID = '$($SUGDeployment.TargetCollectionID)'").Name
	$NewAssignmentName = "$SUGName - $CollectionName"
	Write-Host "SUDeployment [$($SUGDeployment.AssignmentUniqueID)] `n old name [$($SUGDeployment.AssignmentName)] `n new name [$NewAssignmentName]"
	$SUGDeployment.AssignmentName = $NewAssignmentName
	[void]$($SUGDeployment.Put())
	Remove-Variable CollectionName, NewAssignmentName | Out-Null
}
Write-Host "Validating Software Update Deployments"
$SUGdeployments = @(Get-WmiObject -Computer $SiteServer -Namespace "root\SMS\site_$($SiteCode)" -Class SMS_UpdateGroupAssignment -Filter "AssignmentType=5 and AssignedUpdateGroup = $SUGID")
$SUGdeployments | Select-Object AssignmentUniqueID, TargetCollectionID, AssignedUpdateGroup, AssignmentName | Format-Table -AutoSize