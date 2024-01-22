################################################################################
#.SYNOPSIS
#   Compress-ArchiveZPAQ.ps1
#   Compress a folder using zPAQ compression
#.DESCRIPTION
#   Set the zPAQ process priority to low
#   Set the zPAQ process to use all except 1 CPU core
#.PARAMETER Path
#   Specifies the folder/directory/path to archive
#.PARAMETER DestinationPath
#   Specifies the full file name and folder/directory/path to create as the archive file
#.EXAMPLE
#   Compress-ArchiveZPAQ.ps1 -Path C:\MyStuff -DestinationPath C:\MyStuff.zPaq
#.NOTES
#   Additional information about the function or script.
#   ========== Keywords ==========
#   Keywords: compress archive backup zPaq zPaq64
#   ========== Change Log History ==========
#   - 2022/05/02 by Chad@ChadsTech.net - Created
#   === To Do / Proposed Changes ===
#   #TODO: A new Parameter Set for Method instead of CompressionLevel
#   ========== Additional References and Reading ==========
#   - zPAQ Compression: http://mattmahoney.net/dc/zpaq.html
#   - Beyond ZIP Part II – Data DeDuplication Archives for all Windows versions via ZPAQ: https://www.deploymentresearch.com/beyond-zip-part-ii-data-deduplication-archives-for-all-windows-versions-via-zpaq/
#   - Data Deduplication Reference – ZPAQ Benchmarking: https://www.deploymentresearch.com/data-deduplication-reference-zpaq-benchmarking/
########################################################################################################################
#region ############# Parameters and variable initialization ############################## #BOOKMARK: Script Parameters
[CmdletBinding()] #(SupportsShouldProcess=$false, ConfirmImpact="Low")
param (
	[Parameter(Mandatory = $true)][ValidateScript({[System.IO.Directory]::Exists($_) })][string]$Path,
	[Parameter(Mandatory = $true)][string]$DestinationPath,
	[Parameter(Mandatory = $false)][ValidateSet('Optimal','NoCompression','Fastest')][string]$CompressionLevel = 'Optimal'

)
# Get the current script's full path and file name
If ($PSise) { $script:ScriptFile = $PSise.CurrentFile.FullPath }
ElseIf (Test-Path -LiteralPath 'variable:HostInvocation') { $script:ScriptFile = $HostInvocation.MyCommand.Definition }
Else { $script:ScriptFile = $MyInvocation.MyCommand.Definition }
[string]$script:ScriptPath = $(Split-Path -Path $script:ScriptFile -Parent)
#endregion ########## Parameters and variable initialization ###########################################################

#region ############# Functions ############################################################ #BOOKMARK: Script Functions
########################################################################################################################
########################################################################################################################
Function Set-ProcessPriority {
	Write-Host "Setting $zPaqProcName processor priority to Low/Idle"
	try {
		(Get-Process $zPaqProcName).PriorityClass = "Idle" #"BelowNormal"
	} catch {
		Write-Warning "Failed setting Processor Priority to Low/Idle"
	}
}

Function Set-ProcessAffinity {
	Write-Host "Setting $zPaqProcName processor affinity to exclude one logical processor"
	try {
		#Get the number of processors
		[int16]$LogicalProcessors = $(Get-WmiObject -class win32_processor -Property NumberOfLogicalProcessors).NumberOfLogicalProcessors
		#Get a bit mask for the 2 to Nth processor
		$MaxAffinity = ([math]::pow(2,$LogicalProcessors) - 1)
		#Set Processor Affinity to all except the first processor
		(Get-Process $zPaqProcName).ProcessorAffinity = [int16]$($MaxAffinity-1)
	} catch {
		Write-Warning "Failed setting Processor Affinity to exclude 1 processor"
	}
}
########################################################################################################################
########################################################################################################################
#endregion ########## Functions ########################################################################################


#region ############# Initialize ########################################################## #BOOKMARK: Script Initialize
# Set required variables from parameters and auto detection
Set-Variable -Name zPaqExe -Value $(Join-Path -Path $script:ScriptPath -ChildPath 'zPaq64.exe')
Set-Variable -Name zPaqAction -Value 'add' -WhatIf:$false
Set-Variable -Name zPaqProcName -Value 'zPaq64' -WhatIf:$false
Switch ($CompressionLevel) {
	'NoCompression' { Set-Variable -Name zPaqMethod -Value '-method 1' -WhatIf:$false }
	'Fastest' { Set-Variable -Name zPaqMethod -Value '-method 1' -WhatIf:$false }
	Default { Set-Variable -Name zPaqMethod -Value '-method 2' -WhatIf:$false }
}

# Set the number of threads to the number of CPU cores minus 1
[int16]$LogicalProcessors = $(Get-WmiObject -Class win32_processor -Property NumberOfLogicalProcessors).NumberOfLogicalProcessors
Set-Variable -Name zPaqProcThreads -Value "-threads $($LogicalProcessors -1)" -WhatIf:$false
#endregion ########## Initialization ###################################################################################

#region ############# Main Script ############################################################### #BOOKMARK: Script Main
Write-Host "running $zPaqExe $zPaqAction `"$DestinationPath`" `"$Path`" $zPaqMethod $zPaqProcThreads"
Start-Process -FilePath $zPaqExe -ArgumentList $zPaqAction, "`"$DestinationPath`"", "`"$Path`"", $zPaqMethod, $zPaqProcThreads -WindowStyle Normal
Set-ProcessPriority
#Set-ProcessAffinity
#endregion ########## Main Script ######################################################################################

#region ############# Finalization ########################################################## #BOOKMARK: Script Finalize
#endregion ########## Finalization #####################################################################################