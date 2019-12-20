################################################################################
#.SYNOPSIS
#   Start-SCCMPackageDeployment.ps1
#   Run a ConfigMgr Package/Program given a Package Name and Version
#.DESCRIPTION
#   Execute a deployed Package/Program on a remote computer(s) given the Package Name and Version.
#	 This assumes there is only one Deployment know to the remote computer for the given the Package Name and Version.
#	 The script requires administrative rights on the remote computer(s)
#.PARAMETER Computer
#   Computer Name (NetBIOS, IPAddress, or FQDN/Fully Qualified Domain Name) of the remote computer(s) to execute against
#.PARAMETER PackageName
#   ConfigMgr (SCCM) unique Package Name to run
#.PARAMETER PackageVersion
#   ConfigMgr (SCCM) Package Version to run
#.EXAMPLE
#   Start-SCCMPackageDeployment.ps1 -Computer TestComputer1 -PackageName 'ConfigMgr Client Support Tools' -PackageVersion '2.1'
#.NOTES
#   This script is maintained at https://github.com/ChadSimmons/Scripts
#   Additional information about the function or script.
#   ========== Keywords ==========
#   Keywords: SCCM ConfigMgr Package Program Advertisement Deployment ReRun
#   ========== Change Log History ==========
#   - 2017/12/15 by Chad.Simmons@CatapultSystems.com - Created
#   === To Do / Proposed Changes ===
#   - TODO: PSSession for WinRM and DCOM connectivity
#	         use CimSession to connect with WinRM and fallback to RPC/DCOM for all WMI commands
#   - TODO: Alternate Credentials
#				[-Impersonation <ImpersonationLevel>]
#				[-Authentication <AuthenticationLevel>]
#				[-Credential <PSCredential>]
#   - TODO: Multithreading
#				[-AsJob]
#				[-ThrottleLimit <Int32>]
#   - TODO: If Package Name and Version are not specified, dynamically get the values from the remote computer
#   - TODO: Build a GUI form if all parameters are not specified
#   ========== Additional References and Reading ==========
#    - SCCM Trigger Schedules
################################################################################

#Requires -Version 2.0  #PowerShell 2.0-5.1 required
[CmdletBinding()]
Param (
	[Parameter(Mandatory=$false,HelpMessage='Computer Name (NetBIOS, IPAddress, or FQDN) of the remote computer to execute on.')]
	#[ValidateLength(1, 255)][ValidateScript( {Resolve-DNSName -Name $_})][string[]]$Computer = $env:ComputerName,
	[ValidateLength(1, 255)][ValidateScript( {Test-Connection -ComputerName $_})][string[]]$Computer = $env:ComputerName,

   [Parameter(Mandatory=$false,HelpMessage='ConfigMgr (SCCM) unique Package Name to run')]
   [ValidateLength(1,255)][ValidateNotNullorEmpty()][string]$PackageName = 'POS Software',

   [Parameter(Mandatory=$true,HelpMessage='ConfigMgr (SCCM) Package Version to run')][string]$PackageVersion
)

<# DEBUG
$PackageName = 'ConfigMgr Client Support Tools' #'Configuration Manager Client Upgrade Package'
$PackageVersion = '1.0'
$ProgramName = 'Run CMTrace Log Tool' #'Configuration Manager Client Upgrade Program'
#>

Function Get-SCCMScheduleID {
	#.Synopsis
	#	Find a ConfigMgr deployment for a specified PackageName
	Param (
		[Parameter(Mandatory = $false)][ValidateNotNullOrEmpty()][string]$ComputerName = '.',
		[Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$PackageName,
		[Parameter(Mandatory = $true)][int]$PackageVersion
	)
	If ($PSBoundParameters.ContainsKey('PackageVersion')) {
		$Package = get-wmiobject -Computer $ComputerName -query "SELECT PKG_PackageID, PKG_Version, ADV_AdvertisementID, PKG_SourceVersion, PRG_CommandLine, PKG_Name, PRG_ProgramID FROM CCM_SoftwareDistribution Where PKG_Name='$PackageName' and PKG_Version='$PackageVersion'" -namespace "root\ccm\policy\machine\actualconfig"
	} else {
		$Package = get-wmiobject -Computer $ComputerName -query "SELECT PKG_PackageID, PKG_Version, ADV_AdvertisementID, PKG_SourceVersion, PRG_CommandLine, PKG_Name, PRG_ProgramID FROM CCM_SoftwareDistribution Where PKG_Name='$PackageName'" -namespace "root\ccm\policy\machine\actualconfig"
	}
	If ($VerbosePreference -eq 'Continue') {
		If ($null -ne $Package) {
			$PackageDetails = @{}
			$PackageDetails.Add('Computer Name', $ComputerName)
			$PackageDetails.Add('Package Name', $Package.PKG_Name)
			$PackageDetails.Add('Package ID', $Package.PKG_PackageID)
			$PackageDetails.Add('Package Version', $Package.PKG_Version)
			$PackageDetails.Add('Package Source Version', $Package.PKG_SourceVersion)
			$PackageDetails.Add('Program ID (Name)', $Package.PRG_ProgramID)
			$PackageDetails.Add('Program Command Line', $Package.PRG_CommandLine)
			$PackageDetails.Add('Deployment ID', $Package.ADV_AdvertisementID)
			Write-Verbose "Found $($PackageDetails | Out-String)"
		} else {
			Write-Verbose "On $ComputerName, DID NOT FIND Package [$PackageName] version [$PackageVersion]"
		}
	}
	Return (get-wmiobject -Computer $ComputerName -query "SELECT ScheduledMessageID FROM CCM_Scheduler_ScheduledMessage Where ScheduledMessageID like '$($Package.ADV_AdvertisementID)-$($Package.PKG_PackageID)-%'" -namespace "ROOT\ccm\policy\machine\actualconfig").ScheduledMessageID
}

ForEach ($ComputerName in $Computer) {
	$ScheduledMessageID = Get-SCCMScheduleID -ComputerName $ComputerName -PackageName $PackageName -PackageVersion $PackageVersion
	If ($null -ne $ScheduledMessageID) {
		Write-Verbose "On $ComputerName, ScheduledMessageID is $ScheduledMessageID"
		Try {
			Invoke-CimMethod -Computer $Computer -Namespace 'ROOT\ccm' -ClassName 'SMS_Client' -MethodName TriggerSchedule -Arguments @{sScheduleID=$ScheduledMessageID}
			Write-Output "On $ComputerName, triggered $PackageName version $PackageVersion to run"
		} catch {
			Try {
					Invoke-WMIMethod -Computer $Computer -Namespace 'ROOT\ccm' -Class 'SMS_Client' -Name TriggerSchedule -ArgumentList "$ScheduledMessageID"
					#([wmiclass]'ROOT\ccm:SMS_Client').TriggerSchedule("$ScheduledMessageID")
					Write-Output "On $ComputerName, triggered $PackageName version $PackageVersion to run"
			} Catch {
					Write-Error "On $ComputerName, failed to trigger $PackageName version $PackageVersion to run"
			}
		}
	} else {
		Write-Warning "On $ComputerName, no Deployment for $PackageName version $PackageVersion was found."
	}
}