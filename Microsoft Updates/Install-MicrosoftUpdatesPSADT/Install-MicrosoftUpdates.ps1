﻿<#
.SYNOPSIS
	Install multiple Microsoft Updates in a specific order
.DESCRIPTION
.PARAMETER DeploymentType
	The type of deployment to perform. Default is: Install.
.PARAMETER DeployMode
	Specifies whether the installation should be run in Interactive, Silent, or NonInteractive mode. Default is: Interactive. Options: Interactive = Shows dialogs, Silent = No dialogs, NonInteractive = Very silent, i.e. no blocking apps. NonInteractive mode is automatically set if it is detected that the process is not user interactive.
.PARAMETER AllowRebootPassThru
	Allows the 3010 return code (requires restart) to be passed back to the parent process (e.g. SCCM) if detected from an installation. If 3010 is passed back to SCCM, a reboot prompt will be triggered.
.PARAMETER TerminalServerMode
	Changes to "user install mode" and back to "user execute mode" for installing/uninstalling applications for Remote Desktop Session Hosts/Citrix servers.
.PARAMETER DisableLogging
	Disables logging to file for the script. Default is: $false.
.EXAMPLE
    powershell.exe -Command "& { & '.\Deploy-Application.ps1' -DeployMode 'Silent'; Exit $LastExitCode }"
.EXAMPLE
    powershell.exe -Command "& { & '.\Deploy-Application.ps1' -AllowRebootPassThru; Exit $LastExitCode }"
.EXAMPLE
    powershell.exe -Command "& { & '.\Deploy-Application.ps1' -DeploymentType 'Uninstall'; Exit $LastExitCode }"
.EXAMPLE
    Deploy-Application.exe -DeploymentType "Install" -DeployMode "Silent"
.NOTES
	# LICENSE #
	PowerShell App Deployment Toolkit - Provides a set of functions to perform common application deployment tasks on Windows.
	Copyright (C) 2017 - Sean Lillis, Dan Cunningham, Muhammad Mashwani, Aman Motazedian.
	This program is free software: you can redistribute it and/or modify it under the terms of the GNU Lesser General Public License as published by the Free Software Foundation, either version 3 of the License, or any later version. This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
	You should have received a copy of the GNU Lesser General Public License along with this program. If not, see <http://www.gnu.org/licenses/>.

	Toolkit Exit Code Ranges:
	60000 - 68999: Reserved for built-in exit codes in Deploy-Application.ps1, Deploy-Application.exe, and AppDeployToolkitMain.ps1
	69000 - 69999: Recommended for user customized exit codes in Deploy-Application.ps1
	70000 - 79999: Recommended for user customized exit codes in AppDeployToolkitExtensions.ps1
.LINK
	http://psappdeploytoolkit.com
#>
[CmdletBinding()]
Param (
	[Parameter(Mandatory=$false)]
	[ValidateSet('Install','Uninstall','Repair')]
	[string]$DeploymentType = 'Install',
	[Parameter(Mandatory=$false)]
	[ValidateSet('Interactive','Silent','NonInteractive')]
	[string]$DeployMode = 'Interactive',
	[Parameter(Mandatory=$false)]
	[switch]$AllowRebootPassThru = $false,
	[Parameter(Mandatory=$false)]
	[switch]$TerminalServerMode = $false,
	[Parameter(Mandatory=$false)]
	[switch]$DisableLogging = $false
)

Try {
	## Set the script execution policy for this process
	Try { Set-ExecutionPolicy -ExecutionPolicy 'ByPass' -Scope 'Process' -Force -ErrorAction 'Stop' } Catch {}

	##*===============================================
	##* VARIABLE DECLARATION
	##*===============================================
	## Variables: Application
	[string]$appVendor = 'Microsoft'
	[string]$appName = 'Windows Upgrade Readiness Prerequisites'
	[string]$appVersion = '17.05.09' #YY.MM.DD
	[string]$appArch = ''
	[string]$appLang = 'EN'
	[string]$appRevision = '01'
	[string]$appScriptVersion = '1.0.0'
	[string]$appScriptDate = '09/05/2017' #DD/MM/YYYY
	[string]$appScriptAuthor = 'Chad.Simmons@CatapultSystems.com'
	##*===============================================
	## Variables: Install Titles (Only set here to override defaults set by the toolkit)
	[string]$installName = ''
	[string]$installTitle = ''

	##* Do not modify section below
	#region DoNotModify

	## Variables: Exit Code
	[int32]$mainExitCode = 0

	## Variables: Script
	[string]$deployAppScriptFriendlyName = 'Deploy Application'
	[version]$deployAppScriptVersion = [version]'3.8.4'
	[string]$deployAppScriptDate = '26/01/2021'
	[hashtable]$deployAppScriptParameters = $psBoundParameters

	## Variables: Environment
	If (Test-Path -LiteralPath 'variable:HostInvocation') { $InvocationInfo = $HostInvocation } Else { $InvocationInfo = $MyInvocation }
	[string]$scriptDirectory = Split-Path -Path $InvocationInfo.MyCommand.Definition -Parent

	## Dot source the required App Deploy Toolkit Functions
	Try {
		[string]$moduleAppDeployToolkitMain = "$scriptDirectory\AppDeployToolkit\AppDeployToolkitMain.ps1"
		If (-not (Test-Path -LiteralPath $moduleAppDeployToolkitMain -PathType 'Leaf')) { Throw "Module does not exist at the specified location [$moduleAppDeployToolkitMain]." }
		If ($DisableLogging) { . $moduleAppDeployToolkitMain -DisableLogging } Else { . $moduleAppDeployToolkitMain }
	}
	Catch {
		If ($mainExitCode -eq 0){ [int32]$mainExitCode = 60008 }
		Write-Error -Message "Module [$moduleAppDeployToolkitMain] failed to load: `n$($_.Exception.Message)`n `n$($_.InvocationInfo.PositionMessage)" -ErrorAction 'Continue'
		## Exit the script, returning the exit code to SCCM
		If (Test-Path -LiteralPath 'variable:HostInvocation') { $script:ExitCode = $mainExitCode; Exit } Else { Exit $mainExitCode }
	}

	#endregion
	##* Do not modify section above
	##*===============================================
	##* END VARIABLE DECLARATION
	##*===============================================

	If ($deploymentType -ine 'Uninstall' -and $deploymentType -ine 'Repair') {
		##*===============================================
		##* PRE-INSTALLATION
		##*===============================================
		[string]$installPhase = 'Pre-Installation'

		## Show Progress Message (with the default message)
		Show-InstallationProgress -StatusMessage 'Installing Microsoft Updates in preparation for Windows 10' -WindowLocation 'BottomRight' -TopMost $false

		##*===============================================
		##* INSTALLATION
		##*===============================================
		[string]$installPhase = 'Installation'

		If (("$envOSVersionMajor.$envOSVersionMinor" -eq 6.1) -and ($envOSServicePack -eq 'Service Pack 1')) {
			If ($envOSArchitecture -eq '64-Bit') {
				[string]$UpdateFolder = 'Win7SP1x64'
				[string[]]$UpdateList = @('AMD64-all-windows6.1-kb3020369-x64_5393066469758e619f21731fc31ff2d109595445.msu', 'AMD64-all-enabletask_050fed44b45a2ae2ad7dc335a0a0598356919cad.exe', 'AMD64-all-windows6.1-kb2952664-v22-x64_4111c0b7d038ab0dca4439edd7d74a47d6586cfc.msu', 'AMD64-all-windows6.1-kb3080149-x64_f25965cefd63a0188b1b6f4aad476a6bd28b68ce.msu', 'AMD64-all-windows6.1-kb3172605-x64_2bb9bc55f347eee34b1454b50c436eb6fd9301fc.msu', 'AMD64-all-windows6.1-kb4015549-x64_59cf25073f2e8615b01d9719a0a2e2a0a9a92937.msu', 'AMD64-all-windows6.1-kb3150513-x64_6cbb71abc859a82acd6842b5765ab43f981c08e5.msu', 'AMD64-all-windows6.1-kb3150513-x64_e342c7c23665b6e4f6482bbb77eba63e0e4e4be5.msu')
			} else {
				[string]$UpdateFolder = 'Win7SP1x86'
				[string[]]$UpdateList = @('X86-all-windows6.1-kb3020369-x86_82e168117c23f7c479a97ee96c82af788d07452e.msu', 'X86-all-windows6.1-kb2952664-v22-x86_2d894906719949c41742ab49809fd9804e0f84f6.msu', 'X86-all-enabletask_4b2be1b9a03abc90c33c0ffd4eef7ea744c05f5a.exe', 'X86-all-windows6.1-kb3080149-x86_3d35229a4f48ada7b2a0ef048dd424bc2eae63ca.msu', 'X86-all-windows6.1-kb3172605-x86_ae03ccbd299e434ea2239f1ad86f164e5f4deeda.msu', 'X86-all-windows6.1-kb4015549-x86_6d9f286d4e855de6cf9ed2e60ab76247c0c6b422.msu', 'X86-all-windows6.1-kb3150513-x86_5f61401f039dd9792899ef0e1ddc3e2f51563b49.msu', 'X86-all-windows6.1-kb3150513-x86_ea4055e316b81a43d8770a08ce6e8b32f0d9ba26.msu')
			}
		}

		If ($UpdateList.count -gt 0) {
			Install-MSUpdate -Directory "$dirFiles\$UpdateFolder" -File $UpdateList
		} else {
			Write-Log -Message 'No updates defined for this operating system' -Severity 1 -Source $deployAppScriptFriendlyName
		}
    }
	##*===============================================
	##* END SCRIPT BODY
	##*===============================================

	## Call the Exit-Script function to perform final cleanup operations
	Exit-Script -ExitCode $mainExitCode
}
Catch {
	[int32]$mainExitCode = 60001
	[string]$mainErrorMessage = "$(Resolve-Error)"
	Write-Log -Message $mainErrorMessage -Severity 3 -Source $deployAppScriptFriendlyName
	Show-DialogBox -Text $mainErrorMessage -Icon 'Stop'
	Exit-Script -ExitCode $mainExitCode
}