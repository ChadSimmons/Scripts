#requires -Version 3.0
################################################################################################# #BOOKMARK: Script Help
#.SYNOPSIS
#   Functions-FileSigTimestamp.ps1
#   Functions to get and set file modified timestamp based on embedded digital signature's date and time
#.DESCRIPTION
#.EXAMPLE
#   dot-source the functions into memory
#   . $PSCommandPath
#   . <this file>
#   . Functions-FileSigTimestamp.ps1
#.NOTES
#   Additional information about the function or script.
#	https://stackoverflow.com/questions/15515134/get-signing-timetime-stamp-of-a-digital-signature-using-powershell/75417307#75417307
#   ========== Keywords =========================
#   Keywords: Digital Signature Certificate Timestamp LastWriteTime LastModifiedTime
#   ========== Change Log History ===============
#   - 2023/02/09 by @ChadSimmons / Chad.Simmons@Quisitive / @ChadsTech / Chad@ChadsTech.net - created
#   ========== To Do / Proposed Changes =========
#   - #TODO: None
########################################################################################################################
#region ############# Parameters and variable initialization ############################## #BOOKMARK: Script Parameters
[CmdletBinding()] #(SupportsShouldProcess=$false, ConfirmImpact="Low")
Param (
	[Parameter(Mandatory = $false, HelpMessage = 'Full folder directory path and file name to for SigCheck.exe / SigCheck64.exe by SysInternals')][string]$SigCheckFullPath = '.\SigCheck.exe'
)
#endregion ########## Parameters and variable initialization ###########################################################

#region ############# Functions ############################################################ #BOOKMARK: Script Functions
########################################################################################################################
########################################################################################################################
Function Get-FileSigTimestamp {
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)][ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })][String]$FilePath,
		[Parameter(Mandatory = $false)][ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })][String]$SigCheckFullPath = $global:SigCheckFullPath
	)
	$TempFile = [System.IO.Path]::GetTempFileName()
	& $SigCheckFullPath -c -nobanner -w "$TempFile" "$FilePath"
	$FileSig = Import-Csv -Path $TempFile
	$FileSigDate = [datetime]$FileSig.Date
	Remove-Item -Path $TempFile
	If ($FileSigDate -is [datetime] -and $FileSig.Verified -eq 'Signed') {
		Write-Verbose -Message 'File Signature Date determined'
		Return $FileSigDate
	} Else {
		$File = Get-Item -Path $FilePath
		Write-Verbose -Message 'File Signature Date does not exist or could not be determined.  Returning file modified timestamp'
		Return $File.LastWriteTime
	}
}

Function Set-FileModifiedToSigTimestamp {
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)][ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })][String]$FilePath,
		[Parameter(Mandatory = $false)][ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })][String]$SigCheckFullPath = $global:SigCheckFullPath
	)
	$Timestamp = Get-FileSigTimestamp -FilePath $FilePath -SigCheckFullPath $SigCheckFullPath
	Write-Verbose "[$FilePath] digital signature time is [$Timestamp]"
	$File = Get-Item -Path $FilePath
	$FileLastModifiedWas = $File.LastWriteTime
	If ($Timestamp -is [datetime] -and $Timestamp -ne [datetime]$FileLastModifiedWas) {
		$File.LastWriteTime = $Timestamp
		$File = Get-Item -Path $FilePath
		$Timespan = New-Timespan -Start $FileLastModifiedWas -End $File.LastWriteTime
		Write-Verbose "[$FilePath] modified time was [$FileLastModifiedWas] and now is [$($File.LastWriteTime)] and difference of $($Timespan.ToString("dd' days 'hh' hours 'mm' minutes 'ss' seconds'"))"
	} Else {
		Write-Verbose "[$FilePath] modified time is [$FileLastModifiedWas] and has not been modified"
	}
}
########################################################################################################################
########################################################################################################################
#endregion ########## Functions ########################################################################################

#region ############# Initialize ########################################################## #BOOKMARK: Script Initialize
#find SigCheck.exe
$arrSigCheckPathOptions = @($SigCheckFullPath, "$PSScriptRoot\SigCheck64.exe", "$PSScriptRoot\SigCheck.exe", "$env:SystemDrive\Apps\MyApps\SysInternals\SigCheck64.exe", "$env:SystemDrive\Apps\MyApps\SysInternals\SigCheck.exe")
ForEach ($Option in $arrSigCheckPathOptions) {
	Write-Verbose -Message "checking for SigCheck.exe at $option"
	If (Test-Path -Path $Option -PathType Leaf) {
		$global:SigCheckFullPath = $Option
		Remove-Variable -Name arrSigCheckPathOptions
		break
	}
}
If (-not(Test-Path -Path $SigCheckFullPath -PathType Leaf)) {
	Remove-Variable -Name SigCheckFullPath -ErrorAction SilentlyContinue
	Remove-Variable -Name SigCheckFullPath -Scope Global -ErrorAction SilentlyContinue
}

$WriteHostParms = @{ForegroundColor = 'DarkYellow'; BackgroundColor = 'DarkGray'}
Write-Host @WriteHostParms "`$SigCheckFullPath is $SigCheckFullPath"
Write-Host @WriteHostParms 'Loaded in memory Function Get-FileSigTimestamp'
Write-Host @WriteHostParms 'Loaded in memory Function Set-FileModifiedToSigTimestamp'
Write-Host @WriteHostParms 'Example Get-FileSigTimestamp -SigCheckFullPath "C:\Apps\MyApps\Sysinternals\SigCheck.exe" -FilePath "C:\Apps\MyApps\Sysinternals\SigCheck.exe"'
Write-Host @WriteHostParms 'Example Get-ChildItem -Path "C:\Apps\MyApps\Sysinternals" -Filter *.exe | Select-Object -ExpandProperty FullName | ForEach-Object { Set-FileModifiedToSigTimestamp -SigCheckFullPath "C:\Apps\MyApps\Sysinternals\SigCheck.exe" -FilePath $_ }'
Write-Host @WriteHostParms 'Example Get-ChildItem -Path "C:\Apps\MyApps" | Where-Object { $_.Extension -in @(".exe", ".dll") } | Select-Object -ExpandProperty FullName | ForEach-Object { Set-FileModifiedToSigTimestamp -FilePath $_ }'
#endregion ########## Initialization ###################################################################################