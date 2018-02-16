#requires -Version 2
#Set-StrictMode -Version Latest #i.e. Option Explicit (all variables must be declared)
################################################################################
#.SYNOPSIS
#   New-CustomScript.ps1
#   A script Template which utilizes a dot-sourced Function Library for Custom Scripting generally with ConfigMgr/SCCM and related activities
#.DESCRIPTION
#	Custom Exit Code Ranges:
#	- 60000 - 68999: Reserved for built-in exit codes in the script toolkit
#	- 69000 - 69999: Recommended for user customized exit codes in invoking script
#   A set of functions for custom scripts including
#   - logging (CMTrace and Windows Event Log)
#   - common variables (ScriptInfo, etc.)
#   - common functions (read/write registry keys, compress files/folders)
#   - and more
#.PARAMETER FunctionLibraryFile
#   Specifies the full path/folder/directory, name, and extension of the script library
#.EXAMPLE
#   . \New-CustomScript.ps1
#.EXAMPLE
#   . \New-CustomScript.ps1 -FunctionLibraryFile 'C:\Scripts\CustomScriptFunctions.ps1'
#.LINK
#   This script is maintained at https://github.com/ChadSimmons/Scripts
#.NOTES
#   Additional information about the function or script.
#   ========== Keywords ==========
#   Keywords: Custom Scripting Functions Module
#   ========== Change Log History ==========
#   - yyyy/mm/dd by Chad Simmons - Modified $ChangeDescription$
#   - 2017/12/27 by Chad.Simmons@CatapultSystems.com - Created
#   - 2017/12/27 by Chad@ChadsTech.net - Created
#   === To Do / Proposed Changes ===
#	- TODO: ???
#   ========== Additional References and Reading ==========
#   - <link title>: https://domain.url
################################################################################
#region    ######################### Parameters and variable initialization ####
[CmdletBinding()] #(SupportsShouldProcess=$false, ConfirmImpact="Low")
Param (
	[Parameter()][ValidateScript({[IO.File]::Exists($_)})][System.IO.FileInfo]$FunctionLibraryFile,

	[Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0, ParameterSetName = "ParamSet1")]
	[ValidateNotNullOrEmpty()][string]$ParamString,

	[Parameter(ParameterSetName = "ParamSet1")][ValidateScript( {[IO.Directory]::Exists($_)})]
	[System.IO.DirectoryInfo]$ParamPath = "$PWD",

	[Parameter(ParameterSetName = "ParamSet2")] #Parameter Sets https://msdn.microsoft.com/en-us/library/dd878348%28v=vs.85%29.aspx
	[ValidateScript( {Test-Path $_ -PathType 'Container'})]
	[String]$LogPath = "$PWD",

	[Parameter(ParameterSetName = "ParamSet2")][ValidateScript( {Test-Path $_ -PathType 'File'})]
	[String]$ParamFile = "$env:Temp\RandomFile.tmp",

	[Parameter()][ValidateScript( {If ((Split-Path $_ -Leaf).IndexOfAny([IO.Path]::GetInvalidFileNameChars()) -ge 0) { Throw "$(Split-Path $_ -Leaf) contains invalid characters!" } Else { $True } })]
	[string[]]$ParamFile1,

	[Parameter()][ValidateSet("Error", "Warn", "Info", ignorecase = $True)]
	[string]$ParamSelection = "Info",

	[Parameter(Mandatory = $true)][ValidateNotNull()]
	[string]$ParamString2,

	[Parameter(Mandatory = $true)][ValidateNotNullorEmpty()]
	[string]$ParamString3,

	[Parameter()][ValidateLength(1, 255)] #ValidateLength https://msdn.microsoft.com/en-us/library/ms714452(v=vs.85).aspx
	[string]$ParamString5,

	[Parameter(Mandatory = $false, HelpMessage = 'Computer Name (NetBIOS, IPAddress, or FQDN) of the remote computer to execute on.')]
	#[ValidateLength(1, 255)][ValidateScript({Resolve-DNSName -Name $_})][string[]]$Computer = $env:ComputerName,
	[Alias('NetBIOSName', 'NetBIOSNames', 'IPAddress', 'FQDN', 'ComputerName', 'ComputerNames', 'Computers')] #Parameter Aliases https://msdn.microsoft.com/en-us/library/dd878292(v=vs.85).aspx
	[ValidateLength(1, 255)]
	[ValidateCount(1, 25)] #ValidateCount https://msdn.microsoft.com/en-us/library/ms714435(v=vs.85).aspx
	[ValidateScript( {Test-Connection -ComputerName $_ -Count 1 -Quiet})]
	[string[]]$Computer = $env:ComputerName,

	[Parameter()][ValidatePattern('^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$')] #ValidatPatern https://msdn.microsoft.com/en-us/library/ms714454(v=vs.85).aspx
	[string[]]$IPAddress1,

	[Parameter()][ValidateScript( {If ($_ -match '^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$') { $True } Else { Throw "$_ is not an IPV4 Address!" }})]
	[string[]]$IPAddress2,

	[Parameter()][ValidateRange(1, 30)] #ValidateRange https://msdn.microsoft.com/en-us/library/ms714421(v=vs.85).aspx
	[Int16]$ParamInteger = 0,

	[Parameter()]
	[Switch]$ParamSwitch,

	[Parameter()][ValidateCount(1, 10)]
	[String[]]$ParamArray,

	[Parameter()]$LogFile #The default is calculated later in the script to be $ScriptPath\$ScriptBaseName.log
	#More Validation options at https://technet.microsoft.com/en-us/library/dd347600.aspx
	#   and https://blogs.technet.microsoft.com/heyscriptingguy/2011/05/15/simplify-your-powershell-script-with-parameter-validation/
)
#endregion ######################### Parameters and variable initialization ####

End { #Input Processing Order tip to move functions to the bottom of a script https://mjolinor.wordpress.com/2012/03/11/begin-process-end-not-just-for-functions/
	#region    ######################### Debug code
	<#
		$FunctionLibraryFile = "$envUserProfile\Documents\Scripts\CustomScriptFunctions.ps1"
		$ParamString="this is a string"
		$ParamPath="$env:Temp"
		$ParamFile="$ParamPath\ThisScript.log"
		$ParamSelection="Info"
		$ParamInteger=1
		$ParamSwitch=$true
		$ParamArray=@('Element 1','Element 2')
	#>
	#endregion ######################### Debug code

	#region    ######################### Initialization ############################
	#$Global:Console = $true
	#$VerbosePreference = 'Continue'
	Start-Script -LogFile "$env:WinDir\Logs\$($ScriptInfo.BaseName).log" #"$($ScriptInfo.Path)\Logs\$($ScriptInfo.BaseName).log"
	$Progress = @{Activity = "$($ScriptInfo.Name)..."; Status = "Initializing..."} ; Write-Progress @Progress
	#endregion ######################### Initialization ############################

	#region    ######################### Main Script ###############################


	write-Output 'Hello'
	write-Verbose 'Verbose Hello'
	write-Debug 'Debug Hello'

	#Determine if a parameter was passed to the script/function
	If ($PSBoundParameters.ContainsKey('ParamString')) {
		Write-Output 'The script parameter [ParamString] was passed as [' + $ParamString + ']'
	} else {
		Write-Output 'The script parameter [ParamString] was not passed'
	}

	$List = @('1', '2', '3')
	$i = 0
	ForEach ($Item in $List) {
		$i++
		$Progress.Status = "Status [$i of $($List.Count)]"
		Write-Progress @Progress -CurrentOperation 'Current Operation' -PercentComplete $($i / $($List.count) * 100)
		Write-LogMessage -Message "Item $Item" -Type 'Info'
		Start-Sleep -Milliseconds 900
	}


	#endregion ######################### Main Script ###############################
	#region    ######################### Deallocation ##############################
	Write-Output "LogFile is $($ScriptInfo.LogFile)"
	If ($OutputFile) { Write-Output "OutputFile is $OutputFile" }
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

#!!!!!!!!!!!!!!!!!!!! ADD CUSTOM FUNCTIONS HERE !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

################################################################################
################################################################################
#endregion ######################### Functions #################################
}n