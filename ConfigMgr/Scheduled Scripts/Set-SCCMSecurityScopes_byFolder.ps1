################################################################################
#.SYNOPSIS
#   Set-SCCMSecurityScopes_byFolder.ps1
#   Set the ConfigMgr Security Scope for Applications, Packages, and Task Sequences in the 'Production' folder
#.DESCRIPTION
#	Set the security scope for all objects in 'Production' root folders
#
#	This script should be scheduled to run every 1 hour on the Primary Site Server
#.PARAMETER FunctionLibraryFile
#   Specifies the full path/folder/directory, name, and extension of the script library
#.EXAMPLE
#   . \Set-SCCMSecurityScopes_byFolder.ps1
#.EXAMPLE
#   . \Set-SCCMSecurityScopes_byFolder.ps1 -FunctionLibraryFile '\\Server\Share\Scripts\Modules\CustomScriptFunctions.ps1'
#.NOTES
#   Additional information about the function or script.
#   ========== Keywords ==========
#   Keywords:
#   ========== Change Log History ==========
#   - 2018/01/31 by Chad.Simmons@CatapultSystems.com - Created
#   === To Do / Proposed Changes ===
#	- TODO: Consider additional WMI Classes
#		    SMS_TaskSequencePackage
#		    SMS_ConfigurationItemLatest
#		    SMS_ImagePackage
#		    SMS_BootImagePackage
#		    SMS_DriverPackage
#		    SMS_Driver
#		    SMS_SoftwareUpdate
#		    SMS_ConfigurationBaselineInfo
#		    SMS_GlobalCondition
################################################################################
#region    ######################### Parameters and variable initialization ####
[CmdletBinding()] #(SupportsShouldProcess=$false, ConfirmImpact="Low")
    Param (
	    [Parameter()][string]$FunctionLibraryFile = '\\Server\Share\Scripts\Modules\CustomScriptFunctions.ps1'
    )
	#region    ######################### Debug code
	<#
		$FunctionLibraryFile = "$envUserProfile\Documents\Scripts\CustomScriptFunctions.ps1"
	#>
	#endregion ######################### Debug code
#endregion ######################### Parameters and variable initialization ####

End {
	#region    ######################### Initialization ############################
	#$Global:Console = $true
	#$VerbosePreference = 'Continue'
	Start-Script -LogFile "$($ScriptInfo.Path)\Logs\$($ScriptInfo.BaseName).log"
	$Progress = @{Activity = "$($ScriptInfo.Name)..."; Status = "Initializing..."} ; Write-Progress @Progress
	$global:SiteServer = 'CMPrimary'
	$global:SiteCode = 'LAB'
	$ProdFolderName = 'XYZ Scenario'
	$ProdScopeName = 'XYZ-Production'
	$LabScopeName = 'XYZ-Lab'
	Write-LogMessage -Message "Object Folder [$ProdFolderName]"
	Write-LogMessage -Message "Production Scope Name [$ProdScopeName]"
	Write-LogMessage -Message "Lab Scope Name [$LabScopeName]"
	#endregion ######################### Initialization ############################

	#region    ######################### Main Script ###############################
	#Configure Security Scopes for ConfigMgr objects in the Production folder
	$ObjectList = Get-WmiObject -Computer $global:SiteServer -Namespace "ROOT\SMS\Site_$($SiteCode)" -Class SMS_ApplicationLatest -Filter "ObjectPath='/$ProdFolderName'"
	#$ObjectList | Select LocalizedDisplayName
	Write-LogMessage -Message "Processing $($ObjectList.Count) Applications"
	If ($ObjectList.count -gt 0) {
		Update-SCCMObjectSecurityScopes -ObjectID $ObjectList.CI_ID -ObjectType 'Application' -AddScopeName $ProdScopeName -RemoveScopeName $LabScopeName -SiteCode $SiteCode
	}
	Write-Progress @Progress -CurrentOperation 'Processng Packages' #-PercentComplete $($i / $($List.count) * 100)
	$ObjectList = Get-WmiObject -Computer $SiteServer -Namespace "ROOT\SMS\Site_$($SiteCode)" -Class SMS_Package -Filter "ObjectPath='/$ProdFolderName'"
	#$ObjectList | Select Name
	Write-LogMessage -Message "Processing $($ObjectList.Count) Packages"
	Write-LogMessage -Message "Processing Package IDs [$($ObjectList.PackageID -join ',')]"
	If ($ObjectList.count -gt 0) {
		Update-SCCMObjectSecurityScopes -ObjectID $ObjectList.PackageID -ObjectType 'Package' -AddScopeName $ProdScopeName -RemoveScopeName $LabScopeName -SiteCode $SiteCode
	}
	$ObjectList = Get-WmiObject -Computer $SiteServer -Namespace "ROOT\SMS\Site_$($SiteCode)" -Class SMS_TaskSequencePackage -Filter "ObjectPath='/$ProdFolderName'"
	#$ObjectList | Select Name
	Write-LogMessage -Message "Processing $($ObjectList.Count) Task Sequences"
	If ($ObjectList.count -gt 0) {
		Update-SCCMObjectSecurityScopes -ObjectID $ObjectList.CI_ID -ObjectType 'TaskSequence' -AddScopeName $ProdScopeName -RemoveScopeName $LabScopeName -SiteCode $SiteCode
	}

	#Configure Security Scopes for ConfigMgr objects in the non-Production folders (i.e. subfolders to the Produciton folder)
	#This is intentionally not configured to prevent moving object from Prod to Lab

	#endregion ######################### Main Script ###############################
	#region    ######################### Deallocation ##############################
	Write-Output "LogFile is $($ScriptInfo.LogFile)"
	Stop-Script -ReturnCode 0
	#endregion ######################### Deallocation ##############################
}
Begin {
#region    ######################### Functions #################################
################################################################################
################################################################################

#region    ######################### Import Function Library ###################
# Dot source the required Function Library
If (Test-Path -LiteralPath 'variable:HostInvocation') { $InvocationInfo = $HostInvocation } Else { $InvocationInfo = $MyInvocation }
If (-not(Test-Path -LiteralPath $FunctionLibraryFile)) { [string]$FunctionLibraryFile = "$(Split-Path -Path $InvocationInfo.MyCommand.Definition -Parent)\CustomScriptFunctions.ps1" }
If (-not(Test-Path -LiteralPath $FunctionLibraryFile -PathType 'Leaf')) { Throw "[$FunctionLibraryFile] does not exist." }
Try {
	. "$FunctionLibraryFile" -ScriptFullPath "$InvocationInfo.MyCommand.Definition"
} Catch {
	Write-Error -Message "[$FunctionLibraryFile] failed to load: `n$($_.Exception.Message)`n `n$($_.InvocationInfo.PositionMessage)" -ErrorAction 'Continue'
	Exit 2 #Win32 ERROR_FILE_NOT_FOUND
}

#endregion ######################### Import Function Library ###################


################################################################################
################################################################################
#endregion ######################### Functions #################################
}