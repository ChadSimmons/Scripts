<#
.SYNOPSIS
	This script is a template that allows you to extend the toolkit with your own custom functions.
.DESCRIPTION
	The script is automatically dot-sourced by the AppDeployToolkitMain.ps1 script.
.NOTES
    Toolkit Exit Code Ranges:
    60000 - 68999: Reserved for built-in exit codes in Deploy-Application.ps1, Deploy-Application.exe, and AppDeployToolkitMain.ps1
    69000 - 69999: Recommended for user customized exit codes in Deploy-Application.ps1
    70000 - 79999: Recommended for user customized exit codes in AppDeployToolkitExtensions.ps1
.LINK 
	http://psappdeploytoolkit.com
#>
[CmdletBinding()]
Param (
)

##*===============================================
##* VARIABLE DECLARATION
##*===============================================

# Variables: Script
[string]$appDeployToolkitExtName = 'PSAppDeployToolkitExt'
[string]$appDeployExtScriptFriendlyName = 'App Deploy Toolkit Extensions'
[version]$appDeployExtScriptVersion = [version]'1.5.0'
[string]$appDeployExtScriptDate = '02/12/2017'
[hashtable]$appDeployExtScriptParameters = $PSBoundParameters

##*===============================================
##* FUNCTION LISTINGS
##*===============================================

#region Function Install-MSUpdate
Function Install-MSUpdate {
<#
.SYNOPSIS
	Install Microsoft Update(s) in list order
.DESCRIPTION
	Install Microsoft Update(s) of type ".exe", ".msu", or ".msp" in the order listed in the File parameter
.PARAMETER Directory
	Directory containing the updates.
.PARAMETER File
	File in the specified directory
.EXAMPLE
	Install-MSUpdates -Directory "$dirFiles\Win7sp1X64" -File "AMD64-KB123456.msu"
.NOTES
.LINK
	http://psappdeploytoolkit.com
#>
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory=$true)][ValidateNotNullorEmpty()][string]$Directory
		[Parameter(Mandatory=$true)][ValidateNotNullorEmpty()][string[]]$File
	)
	
	Begin {
		## Get the name of this function and write header
		[string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -CmdletBoundParameters $PSBoundParameters -Header
	}
	Process {
		Write-Log -Message "Preparing to install updates in directory [$Directory]." -Source ${CmdletName}
		
		## Get all hotfixes and install if required
		ForEach ($FileName in $File) {
			[IO.FileInfo[]]$UpdateFile = Get-ChildItem -LiteralPath "$Directory\$FileName"
			Write-Log -Message "Preparing to install [$FileName] in directory [$Directory]." -Source ${CmdletName}
			If ($UpdateFile.Name -match 'redist') {
				Show-InstallationProgress -StatusMessage "Installation in Progress...`nInstalling $FileName" -WindowLocation 'BottomRight' -TopMost $false
				[version]$redistVersion = [Diagnostics.FileVersionInfo]::GetVersionInfo($UpdateFile).ProductVersion
				[string]$redistDescription = [Diagnostics.FileVersionInfo]::GetVersionInfo($UpdateFile).FileDescription
				
				Write-Log -Message "Install [$redistDescription $redistVersion]..." -Source ${CmdletName}
				#  Handle older redistributables (ie, VC++ 2005)
				If ($redistDescription -match 'Win32 Cabinet Self-Extractor') {
					Execute-Process -Path $UpdateFile -Parameters '/q' -WindowStyle 'Hidden' -ContinueOnError $true
				}
				Else {
					Execute-Process -Path $UpdateFile -Parameters '/quiet /norestart' -WindowStyle 'Hidden' -ContinueOnError $true
				}
			}
			Else {
				#  Get the KB number of the file
				[string]$kbNumber = [regex]::Match($UpdateFile.Name, $kbPattern).ToString()
				If (-not $kbNumber) { Continue }
				Show-InstallationProgress -StatusMessage "Installation in Progress...`nInstalling $kbNumber" -WindowLocation 'BottomRight' -TopMost $false
				
				#  Check to see whether the KB is already installed
				If (-not (Test-MSUpdates -KBNumber $kbNumber)) {
					Write-Log -Message "KB Number [$KBNumber] was not detected and will be installed." -Source ${CmdletName}
					Switch ($UpdateFile.Extension) {
						#  Installation type for executables (i.e., Microsoft Office Updates)
						'.exe' { Execute-Process -Path $UpdateFile -Parameters '/quiet /norestart' -WindowStyle 'Hidden' -ContinueOnError $true }
						#  Installation type for Windows updates using Windows Update Standalone Installer
						'.msu' { Execute-Process -Path 'wusa.exe' -Parameters "`"$($UpdateFile.FullName)`" /quiet /norestart" -WindowStyle 'Hidden' -ContinueOnError $true }
						#  Installation type for Windows Installer Patch
						'.msp' { Execute-MSI -Action 'Patch' -Path $UpdateFile -ContinueOnError $true }
					}
				}
				Else {
					Write-Log -Message "KB Number [$kbNumber] is already installed. Continue..." -Source ${CmdletName}
				}
			}
		}
	End {
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -Footer
	}
}
#endregion



##*===============================================
##* END FUNCTION LISTINGS
##*===============================================

##*===============================================
##* SCRIPT BODY
##*===============================================

If ($scriptParentPath) {
	Write-Log -Message "Script [$($MyInvocation.MyCommand.Definition)] dot-source invoked by [$(((Get-Variable -Name MyInvocation).Value).ScriptName)]" -Source $appDeployToolkitExtName
}
Else {
	Write-Log -Message "Script [$($MyInvocation.MyCommand.Definition)] invoked directly" -Source $appDeployToolkitExtName
}

##*===============================================
##* END SCRIPT BODY
##*===============================================