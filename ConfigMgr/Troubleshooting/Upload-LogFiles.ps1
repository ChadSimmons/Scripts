#.Synopsis
#   Upload-ConfigMgrClientLogs.ps1
#   Compress ConfigMgr setup logs, client logs, and custom logs and copy to the specified Server or the associated Management Point
#.Notes
#	This script is maintained at https://github.com/ChadSimmons/Scripts
#	Additional information about the function or script.
#   - This script is compatible with PowerShell 2.0 - 5.1 to support Windows 7 default PowerShell version and newer operating systems
#   - This script can be deployed as a ConfigMgr Package, Application, Compliance Setting, or with minor changes a Script
#	========== Change Log History ==========
#	- 2019/04/29 by Chad.Simmons@CatapultSystems.com - resolved additional issues with RedirectStandardOutput, fixed new line issue with GatherLogs CollectedInfo
#	- 2019/04/23 by Chad.Simmons@CatapultSystems.com - resolved issues with RedirectStandardOutput
#	- 2019/04/02 by Chad.Simmons@CatapultSystems.com - added ShareFinalPath, SystemInfo.exe, and C:\Windows\Debug
#	- 2018/10/05 by Chad.Simmons@CatapultSystems.com - too many fixes to track
#	- 2018/06/27 by Chad.Simmons@CatapultSystems.com - Added additional comments/instructions and fixed some syntax errors
#	- 2018/06/14 by Chad.Simmons@CatapultSystems.com - Added additional inventory including from https://www.windowsmanagementexperts.com/configmgr-run-script-collect-logs/configmgr-run-script-collect-logs.htm
#	- 2018/06/13 by Chad.Simmons@CatapultSystems.com - Added function to compress files with PowerShell 2.0 from http://blog.danskingdom.com/module-to-synchronously-zip-and-unzip-using-powershell-2-0
#	- 2017/10/30 by Chad.Simmons@CatapultSystems.com - Created
#	- 2017/10/30 by Chad@ChadsTech.net - Created
#	=== To Do / Proposed Changes ===
#	- TODO: Handle ConfigMgr Script parameter limitations
#	- TODO: Detect if running as a ConfigMgr Script on ConfigMgr Client v1802+ and format output as JSON
#	========== Additional References and Reading ==========
#   - Based on https://blogs.technet.microsoft.com/setprice/2017/08/16/automating-collection-of-config-mgr-client-logs
#   - Based on http://ccmexec.com/2017/10/powershell-script-to-collect-sccm-log-files-from-clients-using-run-script/
#   - Based on https://www.windowsmanagementexperts.com/configmgr-run-script-collect-logs/configmgr-run-script-collect-logs.htm
#   -             https://blogs.msdn.microsoft.com/rkramesh/2016/09/19/sccm-client-log-collection-for-troubleshooting/

[CmdletBinding()]  #[CmdletBinding(SupportsShouldProcess=$False,ConfirmImpact='None')]
Param (
	[Parameter(Mandatory=$true)][string]$ShareFinalPath, #$(Package/Task Sequence ID).$ComputerName
	[string]$ShareBasePath = 'Share\Folder\Subfolder\Logs',
	[string]$LogServer = 'Server.Contoso.com', #if blank will detect ConfigMgr MP
	[string]$DeleteLocalArchive = 'false', #ConfigMgr 1806 only supports String and Int, not [switch].
	[string]$SuppressConsoleOutput = 'true' #ConfigMgr 1806 only supports String and Int, not [switch].  Disabling Console output to control the captured script output
)

#region    ######################### Functions #################################
################################################################################
Function Get-ScriptPath {
	#.Synopsis
	#   Get the folder of the script file
	#.Notes
	#   See snippet Get-ScriptPath.ps1 for excruciating details and alternatives
	If ($psISE -and [string]::IsNullOrEmpty($script:ScriptPath)) {
		$script:ScriptPath = Split-Path $psISE.CurrentFile.FullPath -Parent #this works in psISE and psISE functions
	} else {
		try {
			$script:ScriptPath = Split-Path -Path $((Get-Variable MyInvocation -Scope 1 -ErrorAction SilentlyContinue).Value).MyCommand.Path -Parent
		} catch {
			$script:ScriptPath = "$env:WinDir\Logs"
		}
	}
	Write-Verbose "Function Get-ScriptPath: ScriptPath is $($script:ScriptPath)"
	#Return $script:ScriptPath
}
Function Get-ScriptName {
	#.Synopsis
	#   Get the name of the script file
	#.Notes
	#   See snippet Get-ScriptPath.ps1 for excruciating details and alternatives
	If ($psISE) {
		$script:ScriptName = Split-Path $psISE.CurrentFile.FullPath -Leaf #this works in psISE and psISE functions
	} else {
		$script:ScriptName = ((Get-Variable MyInvocation -Scope 1 -ErrorAction SilentlyContinue).Value).MyCommand.Name
	}
	$script:ScriptBaseName = [System.IO.Path]::GetFileNameWithoutExtension($script:ScriptName)
	Write-Verbose "Function Get-ScriptName: ScriptName is $($script:ScriptName)"
	Write-Verbose "Function Get-ScriptName: ScriptBaseName is $($script:ScriptBaseName)"
	#return $script:ScriptName
}
Function Write-LogMessage {
	#.Synopsis
	#   Write a log entry in CMtrace format
	Param (
		[Parameter(Mandatory = $true)]$Message,
		[ValidateSet('Error', 'Warn', 'Warning', 'Info', 'Information', '1', '2', '3')][string]$Type,
		$Component = $script:ScriptName,
		$LogFile = $script:LogFile,
		[switch]$Console
	)
	Switch ($Type) {
		{ @('3', 'Error') -contains $_ } { $intType = 3 } #3 = Error (red)
		{ @('2', 'Warn', 'Warning') -contains $_ } { $intType = 2 } #2 = Warning (yellow)
		Default { $intType = 1 } #1 = Normal
	}
	If ($null -eq $Component) { $Component = ' ' } #Must not be null
	If ($intType -eq 3) {
		Write-OutputMessage -Message "[ERROR] $Message"
	}
	Write-Verbose "Write-LogMessage [$Message]"
	If ($Console -eq $true -and $SuppressConsoleOutput -ne $true) { Write-Output $Message } #write to console if enabled
	try {
		"<![LOG[$Message]LOG]!><time=`"$(Get-Date -Format "HH:mm:ss.ffffff")`" date=`"$(Get-Date -Format "MM-dd-yyyy")`" component=`"$Component`" context=`"`" type=`"$intType`" thread=`"`" file=`"`">" | Out-File -Append -Encoding UTF8 -FilePath $LogFile
	} catch {
		Write-OutputMessage -Message "[ERROR] Failed to write to the log file [$LogFile]"
		Write-Error "Failed to write to the log file [$LogFile]"
	}
}
Function Write-OutputMessage ($Message) {
	try {
		$script:OutputArray += $Message
	} catch {
		Write-Error "Failed appending message to the output array."
	}
	Write-Verbose -Message "Write-OutputMessage: $Message"
}
Function Start-Script ($LogFile) {
	$script:ScriptStartTime = Get-Date
	If ([string]::IsNullOrEmpty($script:ScriptPath)) { Write-Error 'Get-ScriptPath function must be called first'; Break }
	If ([string]::IsNullOrEmpty($script:ScriptName)) { Write-Error 'Get-ScriptName function must be called first'; Break }

	#If the LogFile is undefined set to \Windows\Logs\<ScriptName>log #<ScriptPath>\<ScriptName>.log
	If ([string]::IsNullOrEmpty($LogFile)) {
		$script:LogFile = "$env:WinDir\Logs\$([System.IO.Path]::GetFileNameWithoutExtension($script:ScriptName)).log"
		#$script:LogFile = "$script:ScriptPath\$([System.IO.Path]::GetFileNameWithoutExtension($script:ScriptName)).log"
	} else { $script:LogFile = $LogFile }

	#If the LogFile folder does not exist, create the folder
	Set-Variable -Name LogPath -Value $(Split-Path -Path $script:LogFile -Parent) -Description 'The folder/directory containing the log file' -Scope Script
	If (-not(Test-Path $LogPath)) { New-Item -Path $LogPath -ItemType Directory -Force}

	Write-LogMessage -Message "==================== SCRIPT START ====================" -Component $script:ScriptName
	Write-LogMessage -Message "Started [$script:ScriptName] from [$script:ScriptPath] on $(Get-Date -Date $script:ScriptStartTime -Format 'F')" -Component $script:ScriptName
	Write-LogMessage -Message "Logging to file [$script:LogFile]" -Component $script:ScriptName
	#Write-OutputMessage -Message "Started [$script:ScriptName] from [$script:ScriptPath] at $script:ScriptStartTime"
}
Function Format-Output ($OutputArray) {
	Write-LogMessage -Message "Format-Output: Outputting $($OutputArray.count) results and issues to the console"
	#ConfigMgr Client version 1802+ automatically appends | ConvertTo-Json
	#   https://docs.microsoft.com/en-us/sccm/apps/deploy-use/create-deploy-scripts
	#   https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/convertfrom-json?view=powershell-5
	#try {
	#    #Write-Output $($OutputArray[$OutputArray.count..0] | ConvertTo-Json)
	#    Write-Output $($OutputArray[$OutputArray.count..0] | ConvertTo-Json | ConvertFrom-Json)
	#    #    function ConvertTo-Json20([object] $item){
	#    #       add-type -assembly system.web.extensions #this requires .NET 3.5 .LINK https://stackoverflow.com/questions/28077854/powershell-2-0-convertfrom-json-and-convertto-json-implementation
	#    #       $ps_js=new-object system.web.script.serialization.javascriptSerializer
	#    #       return $ps_js.Serialize($item)
	#    #    }
	#    #Write-LogMessage -Message "Format-Output: Output as JSON."
	#} catch {
	#    Write-LogMessage -Message "Format-Output: Failed to output to JSON.  Outputting as an array." -Type Warn
	$OutputArray | ForEach-Object { Write-Output $_ }
	#Write-Output $($OutputArray[$OutputArray.count..0])
	#}
}
Function Stop-Script ($ReturnCode) {
	Format-Output -OutputArray $script:OutputArray
	Write-LogMessage -Message "Exiting with return code $ReturnCode"
	$ScriptEndTime = Get-Date
	$ScriptTimeSpan = New-TimeSpan -Start $script:ScriptStartTime -end $ScriptEndTime #New-TimeSpan -seconds $(($(Get-Date)-$StartTime).TotalSeconds)
	Write-LogMessage -Message "Script Completed in $([math]::Round($ScriptTimeSpan.TotalSeconds)) seconds, started at $(Get-Date $script:ScriptStartTime -Format 'yyyy/MM/dd hh:mm:ss'), and ended at $(Get-Date $ScriptEndTime -Format 'yyyy/MM/dd hh:mm:ss')"
	Write-LogMessage -Message "==================== SCRIPT COMPLETE ====================" -Component $script:ScriptName
	Exit $ReturnCode
}
Function Remove-Archive {
	#Delete the local archive file
	If ($script:DeleteLocalArchive -eq $true) {
		Remove-Item -Path "$CCMclientLogsPath\$localArchiveFileName" -ErrorAction SilentlyContinue
		Write-LogMessage -Message "Deleted local log archive [$CCMclientLogsPath\$localArchiveFileName]"
	} Else {
		Write-LogMessage -Message "Not deleting local log archive [$CCMclientLogsPath\$localArchiveFileName]"
	}
}
Function Copy-ItemsEx {
	param(
		[parameter(Mandatory = $true)][string]$Source,
		[parameter(Mandatory = $true)][string]$Destination,
		[parameter()][string]$Filter,
		[parameter()][bool]$Recurse
	)
	If ([string]::IsNullOrEmpty($Filter)) { $Filter = '*.*' }
	#If ($PSBoundParameters.ContainsKey('Recurse')) { $Recurse = $true } Else { $Recurse = $false }

	Write-LogMessage -Message "Attempting to copy [$Filter] from [$Source] to [$Destination]."
	If (Test-Path -Path "$Source" -PathType Container) {
		If (-not(Test-Path -Path "$Destination" -PathType Container)) {
			try {
				$rc = New-Item -itemType Directory -Path "$Destination" -ErrorAction Stop | Out-Null
				Write-LogMessage -Message "   Created path [$Destination]."
			} catch {
				Write-LogMessage -Message "   Failed to create path [$Destination]." -Type Error
			}
		}
		If (Test-Path -Path "$Destination" -PathType Container) {
			try {
				Copy-Item -Path "$Source\$Filter" -Destination "$Destination" -Recurse:$Recurse -Force -ErrorAction Stop
				Write-LogMessage -Message "   Copied [$Filter] from [$Source] to [$Destination] with recurse of $Recurse"
				Write-OutputMessage -Message "   Copied [$Filter] from [$Source] to [$Destination] with recurse of $Recurse"
			} catch {
				Write-LogMessage -Message "   Failed to copy [$Filter] from [$Source] to [$Destination] with recurse of $Recurse" -Type Warning
			}
		}
	} Else {
		Write-LogMessage -Message "   Source path [$Source] not found." -Type Warning
	}
}
Function GetNumberOfItemsInZipFileItems($shellItems) {
	# Recursive function to calculate the total number of files and directories in the Zip file.
	[int]$totalItems = $shellItems.Count
	foreach ($shellItem in $shellItems) {
		if ($shellItem.IsFolder)
		{ $totalItems += GetNumberOfItemsInZipFileItems -shellItems $shellItem.GetFolder.Items() }
	}
	$totalItems
}
Function MoveDirectoryIntoZipFile($parentInZipFileShell, $pathOfItemToCopy) {
	# Recursive function to move a directory into a Zip file, since we can move files out of a Zip file, but not directories, and copying a directory into a Zip file when it already exists is not allowed.
	# Get the name of the file/directory to copy, and the item itself.
	$nameOfItemToCopy = Split-Path -Path $pathOfItemToCopy -Leaf
	if ($parentInZipFileShell.IsFolder)
	{ $parentInZipFileShell = $parentInZipFileShell.GetFolder }
	$itemToCopyShell = $parentInZipFileShell.ParseName($nameOfItemToCopy)

	# If this item does not exist in the Zip file yet, or it is a file, move it over.
	if ($null -eq $itemToCopyShell -or !$itemToCopyShell.IsFolder) {
		$parentInZipFileShell.MoveHere($pathOfItemToCopy)

		# Wait for the file to be moved before continuing, to avoid erros about the zip file being locked or a file not being found.
		while (Test-Path -Path $pathOfItemToCopy)
		{ Start-Sleep -Milliseconds 10 }
	}
	# Else this is a directory that already exists in the Zip file, so we need to traverse it and copy each file/directory within it.
	else {
		# Copy each file/directory in the directory to the Zip file.
		foreach ($item in (Get-ChildItem -Path $pathOfItemToCopy -Force)) {
			MoveDirectoryIntoZipFile -parentInZipFileShell $itemToCopyShell -pathOfItemToCopy $item.FullName
		}
	}
}
Function MoveFilesOutOfZipFileItems($shellItems, $directoryToMoveFilesToShell, $fileNamePrefix) {
	# Recursive function to move all of the files that start with the File Name Prefix to the Directory To Move Files To.
	# Loop through every item in the file/directory.
	foreach ($shellItem in $shellItems) {
		# If this is a directory, recursively call this function to iterate over all files/directories within it.
		if ($shellItem.IsFolder) {
			$totalItems += MoveFilesOutOfZipFileItems -shellItems $shellItem.GetFolder.Items() -directoryToMoveFilesTo $directoryToMoveFilesToShell -fileNameToMatch $fileNameToMatch
		}
		# Else this is a file.
		else {
			# If this file name starts with the File Name Prefix, move it to the specified directory.
			if ($shellItem.Name.StartsWith($fileNamePrefix)) {
				$directoryToMoveFilesToShell.MoveHere($shellItem)
			}
		}
	}
}
Function Compress-ZipFile {
	[CmdletBinding()]
	param (
		[parameter(Position = 1, Mandatory = $true)]
		[ValidateScript( {Test-Path -Path $_})]
		[string]$FileOrDirectoryPathToAddToZipFile,

		[parameter(Position = 2, Mandatory = $false)]
		[string]$ZipFilePath,

		[Alias("Force")]
		[switch]$OverwriteWithoutPrompting
	)

	BEGIN {
		Write-LogMessage -Message "Starting Function Compress-ZipFile -FileOrDirectoryPathToAddToZipFile $FileOrDirectoryPathToAddToZipFile -ZipFilePath $ZipFilePath -OverwriteWithoutPrompting $OverwriteWithoutPrompting..."
	}
	END {
		Write-LogMessage -Message "Completed Function Compress-ZipFile"
	}
	PROCESS {
		# If a Zip File Path was not given, create one in the same directory as the file/directory being added to the zip file, with the same name as the file/directory.
		if ($null -eq $ZipFilePath -or $ZipFilePath.Trim() -eq [string]::Empty) { $ZipFilePath = Join-Path -Path $FileOrDirectoryPathToAddToZipFile -ChildPath '.zip' }

		# If the Zip file to create does not have an extension of .zip (which is required by the shell.application), add it.
		if (!$ZipFilePath.EndsWith('.zip', [StringComparison]::OrdinalIgnoreCase)) { $ZipFilePath += '.zip' }

		# If the Zip file to add the file to does not exist yet, create it.
		if (-not(Test-Path -Path $ZipFilePath -PathType Leaf)) { New-Item -Path $ZipFilePath -ItemType File > $null }

		# Get the Name of the file or directory to add to the Zip file.
		$fileOrDirectoryNameToAddToZipFile = Split-Path -Path $FileOrDirectoryPathToAddToZipFile -Leaf

		# Get the number of files and directories to add to the Zip file.
		$numberOfFilesAndDirectoriesToAddToZipFile = (Get-ChildItem -Path $FileOrDirectoryPathToAddToZipFile -Recurse -Force).Count

		# Get if we are adding a file or directory to the Zip file.
		$itemToAddToZipIsAFile = Test-Path -Path $FileOrDirectoryPathToAddToZipFile -PathType Leaf

		# Get Shell object and the Zip File.
		try {
			$shell = New-Object -ComObject Shell.Application
			$zipShell = $shell.NameSpace($ZipFilePath)
		} catch {
			throw $_
		}

		# We will want to check if we can do a simple copy operation into the Zip file or not. Assume that we can't to start with.
		# We can if the file/directory does not exist in the Zip file already, or it is a file and the user wants to be prompted on conflicts.
		$canPerformSimpleCopyIntoZipFile = $false

		# If the file/directory does not already exist in the Zip file, or it does exist, but it is a file and the user wants to be prompted on conflicts, then we can perform a simple copy into the Zip file.
		$fileOrDirectoryInZipFileShell = $zipShell.ParseName($fileOrDirectoryNameToAddToZipFile)
		$itemToAddToZipIsAFileAndUserWantsToBePromptedOnConflicts = ($itemToAddToZipIsAFile -and !$OverwriteWithoutPrompting)
		if ($null -eq $fileOrDirectoryInZipFileShell -or $itemToAddToZipIsAFileAndUserWantsToBePromptedOnConflicts) {
			$canPerformSimpleCopyIntoZipFile = $true
		}

		# If we can perform a simple copy operation to get the file/directory into the Zip file.
		if ($canPerformSimpleCopyIntoZipFile) {
			# Start copying the file/directory into the Zip file since there won't be any conflicts. This is an asynchronous operation.
			$zipShell.CopyHere($FileOrDirectoryPathToAddToZipFile)	# Copy Flags are ignored when copying files into a zip file, so can't use them like we did with the Expand-ZipFile function.

			# The Copy operation is asynchronous, so wait until it is complete before continuing.
			# Wait until we can see that the file/directory has been created.
			while ($null -eq $zipShell.ParseName($fileOrDirectoryNameToAddToZipFile))
			{ Start-Sleep -Milliseconds 100 }

			# If we are copying a directory into the Zip file, we want to wait until all of the files/directories have been copied.
			if (!$itemToAddToZipIsAFile) {
				# Get the number of files and directories that should be copied into the Zip file.
				$numberOfItemsToCopyIntoZipFile = (Get-ChildItem -Path $FileOrDirectoryPathToAddToZipFile -Recurse -Force).Count

				# Get a handle to the new directory we created in the Zip file.
				$newDirectoryInZipFileShell = $zipShell.ParseName($fileOrDirectoryNameToAddToZipFile)

				# Wait until the new directory in the Zip file has the expected number of files and directories in it.
				while ((GetNumberOfItemsInZipFileItems -shellItems $newDirectoryInZipFileShell.GetFolder.Items()) -lt $numberOfItemsToCopyIntoZipFile)
				{ Start-Sleep -Milliseconds 100 }
			}
		}
		# Else we cannot do a simple copy operation. We instead need to move the files out of the Zip file so that we can merge the directory, or overwrite the file without the user being prompted.
		# We cannot move a directory into the Zip file if a directory with the same name already exists, as a MessageBox warning is thrown, not a conflict resolution prompt like with files.
		# We cannot silently overwrite an existing file in the Zip file, as the flags passed to the CopyHere/MoveHere functions seem to be ignored when copying into a Zip file.
		else {
			# Create a temp directory to hold our file/directory.
			$tempDirectoryPath = $null
			$tempDirectoryPath = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ([System.IO.Path]::GetRandomFileName())
			New-Item -Path $tempDirectoryPath -ItemType Container > $null

			# If we will be moving a directory into the temp directory.
			$numberOfItemsInZipFilesDirectory = 0
			if ($fileOrDirectoryInZipFileShell.IsFolder) {
				# Get the number of files and directories in the Zip file's directory.
				$numberOfItemsInZipFilesDirectory = GetNumberOfItemsInZipFileItems -shellItems $fileOrDirectoryInZipFileShell.GetFolder.Items()
			}

			# Start moving the file/directory out of the Zip file and into a temp directory. This is an asynchronous operation.
			$tempDirectoryShell = $shell.NameSpace($tempDirectoryPath)
			$tempDirectoryShell.MoveHere($fileOrDirectoryInZipFileShell)

			# If we are moving a directory, we need to wait until all of the files and directories in that Zip file's directory have been moved.
			$fileOrDirectoryPathInTempDirectory = Join-Path -Path $tempDirectoryPath -ChildPath $fileOrDirectoryNameToAddToZipFile
			if ($fileOrDirectoryInZipFileShell.IsFolder) {
				# The Move operation is asynchronous, so wait until it is complete before continuing. That is, sleep until the Destination Directory has the same number of files as the directory in the Zip file.
				while ((Get-ChildItem -Path $fileOrDirectoryPathInTempDirectory -Recurse -Force).Count -lt $numberOfItemsInZipFilesDirectory)
				{ Start-Sleep -Milliseconds 100 }
			}
			# Else we are just moving a file, so we just need to check for when that one file has been moved.
			else {
				# The Move operation is asynchronous, so wait until it is complete before continuing.
				while (!(Test-Path -Path $fileOrDirectoryPathInTempDirectory))
				{ Start-Sleep -Milliseconds 100 }
			}

			# We want to copy the file/directory to add to the Zip file to the same location in the temp directory, so that files/directories are merged.
			# If we should automatically overwrite files, do it.
			if ($OverwriteWithoutPrompting) {
				Copy-Item -Path $FileOrDirectoryPathToAddToZipFile -Destination $tempDirectoryPath -Recurse -Force
			}
			# Else the user should be prompted on each conflict.
			else {
				Copy-Item -Path $FileOrDirectoryPathToAddToZipFile -Destination $tempDirectoryPath -Recurse -Confirm -ErrorAction SilentlyContinue
			}	# SilentlyContinue errors to avoid an error for every directory copied.

			# For whatever reason the zip.MoveHere() function is not able to move empty directories into the Zip file, so we have to put dummy files into these directories
			# and then remove the dummy files from the Zip file after.
			# If we are copying a directory into the Zip file.
			$dummyFileNamePrefix = 'Dummy.File'
			[int]$numberOfDummyFilesCreated = 0
			if ($fileOrDirectoryInZipFileShell.IsFolder) {
				# Place a dummy file in each of the empty directories so that it gets copied into the Zip file without an error.
				$emptyDirectories = Get-ChildItem -Path $fileOrDirectoryPathInTempDirectory -Recurse -Force -Directory | Where-Object { $null -eq (Get-ChildItem -Path $_ -Force) }
				foreach ($emptyDirectory in $emptyDirectories) {
					$numberOfDummyFilesCreated++
					New-Item -Path (Join-Path -Path $emptyDirectory.FullName -ChildPath "$dummyFileNamePrefix$numberOfDummyFilesCreated") -ItemType File -Force > $null
				}
			}

			# If we need to copy a directory back into the Zip file.
			if ($fileOrDirectoryInZipFileShell.IsFolder) {
				MoveDirectoryIntoZipFile -parentInZipFileShell $zipShell -pathOfItemToCopy $fileOrDirectoryPathInTempDirectory
			}
			# Else we need to copy a file back into the Zip file.
			else {
				# Start moving the merged file back into the Zip file. This is an asynchronous operation.
				$zipShell.MoveHere($fileOrDirectoryPathInTempDirectory)
			}

			# The Move operation is asynchronous, so wait until it is complete before continuing.
			# Sleep until all of the files have been moved into the zip file. The MoveHere() function leaves empty directories behind, so we only need to watch for files.
			do {
				Start-Sleep -Milliseconds 100
				$files = Get-ChildItem -Path $fileOrDirectoryPathInTempDirectory -Force -Recurse | Where-Object { !$_.PSIsContainer }
			} while ($null -ne $files)

			# If there are dummy files that need to be moved out of the Zip file.
			if ($numberOfDummyFilesCreated -gt 0) {
				# Move all of the dummy files out of the supposed-to-be empty directories in the Zip file.
				MoveFilesOutOfZipFileItems -shellItems $zipShell.items() -directoryToMoveFilesToShell $tempDirectoryShell -fileNamePrefix $dummyFileNamePrefix

				# The Move operation is asynchronous, so wait until it is complete before continuing.
				# Sleep until all of the dummy files have been moved out of the zip file.
				do {
					Start-Sleep -Milliseconds 100
					[Object[]]$files = Get-ChildItem -Path $tempDirectoryPath -Force -Recurse | Where-Object { !$_.PSIsContainer -and $_.Name.StartsWith($dummyFileNamePrefix) }
				} while ($null -eq $files -or $files.Count -lt $numberOfDummyFilesCreated)
			}
			# Delete the temp directory that we created.
			Remove-Item -Path $tempDirectoryPath -Force -Recurse > $null
		}
	}
}
Function GatherLogs( [string]$CustomInventoryFile) {
	#.SYNOPSIS Gather logs
	#.LINK https://blogs.msdn.microsoft.com/rkramesh/2016/09/19/sccm-client-log-collection-for-troubleshooting

	[string]$CollectedInfo
	#Collect the IPConfig /All
	$CollectedInfo += "Collecting : IPConfig"
	$colItems = Get-WmiObject -class 'Win32_NetworkAdapterConfiguration' | Where-Object {$_.IPEnabled -Match "True"}
	foreach ($objItem in $colItems) {
		$CollectedInfo += "`t" + $objItem.Description
		$CollectedInfo += "`t `t Physical Address. . . . . . . . . : " + $objItem.MACAddress
		$CollectedInfo += "`t `t IPv4v6 Address. . . . . . . . . . : " + $objItem.IPAddress
		$CollectedInfo += "`t `t Subnet Mask . . . . . . . . . . . : " + $objItem.IPSubnet
		$CollectedInfo += "`t `t IPEnabled . . . . . . . . . . . . : " + $objItem.IPEnabled
		$CollectedInfo += "`t `t DNS Servers . . . . . . . . . . . : " + $objItem.DNSServerSearchOrder
		$CollectedInfo += "`t `t DHCP Server . . . . . . . . . . . : " + $objItem.DHCPServer
		$CollectedInfo += "`t `t DNS Suffix Search List. . . . . . : " + $objItem.DNSDomainSuffixSearchOrder
	}
	# Collect the CCMCache folder info
	$CollectedInfo += "`nCollecting : CCMCache Info"
	$CCMCacheFolder = "$env:WinDir\ccmcache" #TODO: Detect This, don't assume
	#$CCMCacheSizeGB = "{0:N2}" -f $((Get-ChildItem $CCMCacheFolder -Recurse | Measure-Object -Sum Length).sum / 1GB)
	$colItems = (Get-ChildItem $CCMCacheFolder | Where-Object {$_.PSIsContainer -eq $True} | Sort-Object)
	$CCMCacheSize = 0
	$CCMCache = ForEach ($i in $colItems) {
		$subFolderItems = (Get-ChildItem $i.FullName -Recurse | Where-Object { $_.PSIsContainer -eq $false } | Measure-Object -property length -sum).sum
		#$CCMCachSize=$CCMCachSize+"{0:N2}" -f ($subFolderItems / 1MB)
		$CCMCacheSize += $subFolderItems
		$props = @{
			GB            = "{0:N2}" -f ($subFolderItems / 1GB)
			MB            = "{0:N2}" -f ($subFolderItems / 1MB)
			Bytes         = $subFolderItems
			DirectoryName = $i.FullName
		}
		New-Object -TypeName PSobject -Property $props
	}
	$CCMCacheSizeGB = "{0:N2}" -f ($CCMCacheSize / 1GB)
	$RC = $CCMCache | Export-CSV ($TempPath + "\CCMCache Content Items " + $CCMCacheSizeGB + ' GB.csv') -NoTypeInformation
	$RC = Get-ChildItem -Path $CCMCacheFolder -File -Recurse | Select-Object Length, LastWriteTime, Name, DirectoryName  | Export-CSV ($TempPath + '\CCMCache Content Files.csv') -NoTypeInformation

	If ($CCMCacheSizeGB -gt 5) {$CollectedInfo += "`t `t `t Warning: CCMCache folder size is more than 5 GB" }
	$CollectedInfo += "`t `t `t CCMCache folder size is " + $CCMCacheSizeGB + ' GB'

	## Applications installed
	#Write-Host "`t - Collecting : Installed Applications"
	#$InstalledApp = Wmic Product | Format-Table -AutoSize | Out-String -Width 1024 | Out-File ($FolderPath.FullName + "\SoftwareInstalled.txt")
	#LogInfo ("`t - Collecting : Installed Applications")

	ForEach ($Line in $CollectedInfo) {	$Line | Out-File -FilePath "$CustomInventoryFile" -Force -Append }
	#$CollectedInfo | Out-File -FilePath "$CustomInventoryFile" -Force
}
################################################################################
#endregion ######################### Functions #################################

#region    ######################### Main Script ###############################
$script:ScriptNameInternal = 'Upload-LogFiles.ps1'
Get-ScriptPath
Get-ScriptName
Start-Script -Component $script:ScriptName
#If Running as SYSTEM such as via a ConfigMgr Script/Package/Application/Compliance Setting, set SuppressConsoleOutput to True so the only output is the final status which can be captured by Scripts and Compliance Settings
If ($(Get-WMIObject -Class Win32_Process -Filter "ProcessID='$PID'" | ForEach-Object { $_.GetOWner().User }) -eq 'SYSTEM') {
	Write-LogMessage -Message "Script running as SYSTEM.  Assume it is from ConfigMgr, suppress console output and reset the ScriptName to the value of ScriptNameInternal"  -Component $script:ScriptName
	$SuppressConsoleOutput = $true
	If ($script:ScriptName -ne $script:ScriptNameInternal) {
		$script:ScriptName = $script:ScriptNameInternal
		$script:ScriptBaseName = [System.IO.Path]::GetFileNameWithoutExtension($script:ScriptName)
		$LogFileOld = $script:LogFile
		$script:LogFile = "$env:WinDir\Logs\$([System.IO.Path]::GetFileNameWithoutExtension($script:ScriptName)).log"
		Write-LogMessage -Message "Restarting logging at [$script:LogFile]"  -Component $script:ScriptName -LogFile $LogFileOld
		Start-Script -Component $script:ScriptName
		Write-LogMessage -Message "Restarted logging.  Previous log file was [$LogFileOld]"  -Component $script:ScriptName
		Write-LogMessage -Message "Script running as SYSTEM.  Assume it is from ConfigMgr, suppress console output and reset the ScriptName to the value of ScriptNameInternal"  -Component $script:ScriptName
	}
}
$LogServerLogsURIPath = $("http://$LogServer/$ShareBasePath/$ShareFinalPath").Replace('\', '/')
$LogServerLogsUNCPath = $("\\$LogServer\$ShareBasePath\$ShareFinalPath").Replace('/', '\')
$TempPath = "$env:Temp\$([System.Guid]::NewGuid().ToString())"
$remoteArchiveFileName =  "$($env:ComputerName).$(Get-Date -format 'yyyyMMdd_HHmm').zip"
$localArchiveFileName = "ConfigMgrClientLogArchive.$(Get-Date -format 'yyyyMMdd_HHmm').zip"
$ReturnCode = 0
$script:OutputArray = @()
#If (-not($PSBoundParameters.ContainsKey('DeleteLocalArchive'))) { $DeleteLocalArchive = $false }
If ($DeleteLocalArchive -eq 'false' -or $DeleteLocalArchive -eq $false) { $DeleteLocalArchive = $false } Else { $DeleteLocalArchive = $true }

Write-Verbose -Message $("Initial Variables:`n LogServerLogsUNCPath = $LogServerLogsUNCPath `n LogServerLogsURIPath = $LogServerLogsURIPath `n TempPath = $TempPath `n remoteArchiveFileName = $remoteArchiveFileName `n localArchiveFileName = $localArchiveFileName `n")
Write-LogMessage -Message "LogServer = $LogServer"
Write-LogMessage -Message "ShareBasePath = $ShareBasePath"
Write-LogMessage -Message "ShareFinalPath = $ShareFinalPath"
Write-LogMessage -Message "LogServerLogsUNCPath = $LogServerLogsUNCPath"
Write-LogMessage -Message "LogServerLogsURIPath = $LogServerLogsURIPath"
Write-LogMessage -Message "TempPath = $TempPath"
Write-LogMessage -Message "remoteArchiveFileName = $remoteArchiveFileName"
Write-LogMessage -Message "localArchiveFileName = $localArchiveFileName"
Write-LogMessage -Message "DeleteLocalArchive = $DeleteLocalArchive"

#Create the Temporary folder
If (-not(Test-Path -Path "$TempPath" -PathType Container)) {
	try {
		$RC = New-Item -ItemType Directory -Path "$TempPath" -ErrorAction Stop | Out-Null
		Write-LogMessage -Message "Created path [$TempPath]."
	} catch {
		Write-LogMessage -Message "Failed to create path [$TempPath]." -Type Error
		Write-OutputMessage -Message "Failed to create path [$TempPath]."
		Stop-Script -ReturnCode -2
	}
}

#Get GPResult
Write-LogMessage -Message "Getting GPResult output in HTML format"
#$rc = Start-Process -NoNewWindow -RedirectStandardOutput "$TempPath\GPResult.StdOut" -RedirectStandardError "$TempPath\GPResult.StdErr" -FilePath "$env:WinDir\System32\GPResult.exe" -ArgumentList '/scope', 'computer', '/h', "$TempPath\GPResult.html"
$rc = Start-Process -NoNewWindow -FilePath "$env:WinDir\System32\GPResult.exe" -ArgumentList '/scope', 'computer', '/h', "$TempPath\GPResult.html" #disabled Redirects to address issue with the files being locked and the archive failing

#get System Info
Write-LogMessage -Message 'Write SystemInfo.exe output'
#Start-Process -FilePath "$env:WinDir\System32\SystemInfo.exe" -ArgumentList '/FO','LIST','| find /V',"`"ÿ`" `"$SystemInfoLocalLog`"" -Wait
$pinfo = New-Object System.Diagnostics.ProcessStartInfo
$pinfo.FileName = "$env:WinDir\System32\SystemInfo.exe"
$pinfo.RedirectStandardError = $true
$pinfo.RedirectStandardOutput = $true
$pinfo.UseShellExecute = $false
$pinfo.Arguments = "/FO LIST"
$p = New-Object System.Diagnostics.Process
$p.StartInfo = $pinfo
$p.Start() | Out-Null
$p.WaitForExit(60000)
$stdout = $p.StandardOutput.ReadToEnd()
#$stderr = $p.StandardError.ReadToEnd()
#Write-Host "stdout: $stdout"
#Write-Host "stderr: $stderr"
#Write-Host "exit code: " + $p.ExitCode
$stdout | Out-File -FilePath "$TempPath\SystemInfo.txt" -Force

#Gather custom inventory, logs and other information
#Set-Variable -Name CustomInventoryFile -Scope Script -Value "$TempPath\CustomInventory.txt"
GatherLogs -CustomInventoryFile "$TempPath\CustomInventory.txt"

#Get Installed MS Patches
#from https://blogs.msdn.microsoft.com/rkramesh/2016/09/19/sccm-client-log-collection-for-troubleshooting
Write-LogMessage -Message "Running WMIC QFE GET"
#$rc = Start-Process -FilePath "$env:WinDir\System32\wbem\WMIC.exe" -ArgumentList 'QFE','GET' -Wait -NoNewWindow | Format-Table -AutoSize | Out-String -Width 1024 | Export-CSV "$TempPath\SoftwareUpdate.csv"
$rc = Start-Process -Wait -NoNewWindow -RedirectStandardError "$TempPath\SoftwareUpdates.StdErr" -FilePath "$env:WinDir\System32\wbem\WMIC.exe" -ArgumentList 'QFE', 'GET' -RedirectStandardOutput "$TempPath\SoftwareUpdates.csv"

#Get Windows Update log
#from https://www.windowsmanagementexperts.com/configmgr-run-script-collect-logs/configmgr-run-script-collect-logs.htm
Write-LogMessage -Message "Copying Windows Update logs"
if ((Get-WmiObject -class Win32_OperatingSystem).version -lt 9) {
	Copy-Item -Path "$env:WinDir\WindowsUpdate.log" -Destination "$TempPath\WindowsUpdate.log"
} else {
	Get-WindowsUpdateLog -LogPath "$TempPath\WindowsUpdate.log"
}

#Get Windows Event logs (export)
$eventLogsPath = "$TempPath\EventLogs"
Write-LogMessage -Message "Exporting Event Logs to [$TempPath\EventLogs]"
New-Item -Path $eventLogsPath -ItemType directory -Force | Out-Null
#This is effectively duplicated
#Start-Process -Wait -NoNewWindow -FilePath "$env:SystemDir\System32\wevtutil.exe" -ArgumentList "epl System `"$eventLogsPath\System.evtx`""
#Start-Process -Wait -NoNewWindow -FilePath "$env:SystemDir\System32\wevtutil.exe" -ArgumentList "epl Application `"$eventLogsPath\Application.evtx`""
#Start-Process -Wait -NoNewWindow -FilePath "$env:SystemDir\System32\wevtutil.exe" -ArgumentList "epl Microsoft-Windows-MBAM/Admin `"$eventLogsPath\MBAM-Admin.evtx`""
#Start-Process -Wait -NoNewWindow -FilePath "$env:SystemDir\System32\wevtutil.exe" -ArgumentList "epl Microsoft-Windows-MBAM/Operational `"$eventLogsPath\MBAM-Operational.evtx`""
#Start-Process -Wait -NoNewWindow -FilePath "$env:SystemDir\System32\wevtutil.exe" -ArgumentList "epl Microsoft-Windows-BitLocker/BitLocker Management `"$eventLogsPath\BitLocker-Management.evtx`""
#Start-Process -Wait -NoNewWindow -FilePath "$env:SystemDir\System32\wevtutil.exe" -ArgumentList "epl Microsoft-Windows-BitLocker/BitLocker Operational `"$eventLogsPath\BitLocker-Operational.evtx`""
#Start-Process -Wait -NoNewWindow -FilePath "$env:SystemDir\System32\wevtutil.exe" -ArgumentList "epl `"Key Management Service`" `"$eventLogsPath\Key Management Service.evtx`""
#Start-Process -Wait -NoNewWindow -FilePath "$env:SystemDir\System32\wevtutil.exe" -ArgumentList "epl `"Microsoft-Windows-Windows Defender/Operational`" `"$eventLogsPath\Windows Defender-Operational.evtx`""
#Start-Process -Wait -NoNewWindow -FilePath "$env:SystemDir\System32\wevtutil.exe" -ArgumentList "epl `"Microsoft-Windows-Provisioning-Diagnostics-Provider/Admin`" `"$eventLogsPath\Windows Provisioning-Admin.evtx`""
#Start-Process -Wait -NoNewWindow -FilePath "$env:SystemDir\System32\wevtutil.exe" -ArgumentList "epl `"Microsoft-Windows-Provisioning-Diagnostics-Provider/AutoPilot`" `"$eventLogsPath\Windows Provisioning-AutoPilot.evtx`""

#Set initial log folders to capture
$LogPaths = @() #create a hashtable of Log Names and Paths.  The ConfigMgr client logs and ccmsetup logs are added to the list later
$LogPaths += @{'LogName' = 'SMSTSRootLogs'; 'LogPath' = "$env:SystemDrive\_SMSTaskSequence\Logs"; 'LogFilter' = '*.*'; 'Recurse' = $true}
$LogPaths += @{'LogName' = 'SMSTSTempLogs'; 'LogPath' = "$env:WinDir\Temp\SMSTS"; 'LogFilter' = '*.*'; 'Recurse' = $true}
$LogPaths += @{'LogName' = 'WinDirLogs'; 'LogPath' = "$env:WinDir\Logs"; 'LogFilter' = '*.*'; 'Recurse' = $false}
$LogPaths += @{'LogName' = 'WinDirLogsSoftware'; 'LogPath' = "$env:WinDir\Logs\Software"; 'LogFilter' = '*.*'; 'Recurse' = $true}
$LogPaths += @{'LogName' = 'RootWindowsBTPanther'; 'LogPath' = "$env:SystemDrive\`$WINDOWS.~BT\Sources\Panther"; 'LogFilter' = '*.*'; 'Recurse' = $true}
$LogPaths += @{'LogName' = 'RootWindowsBTRollback'; 'LogPath' = "$env:SystemDrive\`$WINDOWS.~BT\Sources\Rollback"; 'LogFilter' = '*.*'; 'Recurse' = $true}
$LogPaths += @{'LogName' = 'PKG_LOGS'; 'LogPath' = "$env:SystemRoot\SysWOW64\PKG_LOGS"; 'LogFilter' = '*.*'; 'Recurse' = $true}
$LogPaths += @{'LogName' = 'WindowsPanther'; 'LogPath' = "$env:WinDir\Panther"; 'LogFilter' = '*.*'; 'Recurse' = $true}
$LogPaths += @{'LogName' = 'WindowsDebug'; 'LogPath' = "$env:WinDir\Debug"; 'LogFilter' = '*.*'; 'Recurse' = $true}
$LogPaths += @{'LogName' = 'WindowsWinEvtLogs'; 'LogPath' = "$env:SystemRoot\System32\winevt\Logs"; 'LogFilter' = '*.*'; 'Recurse' = $true}
$LogPaths += @{'LogName' = '1ETachyon'; 'LogPath' = "$env:ProgramData\1E\Tachyon"; 'LogFilter' = '*.log'; 'Recurse' = $true}
$LogPaths += @{'LogName' = '1ENomad'; 'LogPath' = "$env:ProgramData\1E\NomadBranch\LogFiles"; 'LogFilter' = '*.log'; 'Recurse' = $true}
#File: $LogPaths += @{'LogName' = 'WindowsCBS'; 'LogPath' = "$env:SystemRoot\Logs\CBS\CBS.log"; 'LogFilter' = '*.*'; 'Recurse' = $false}
#File: $LogPaths += @{'LogName' = 'WindowsSetupAPIUpgrade'; 'LogPath' = "$env:SystemRoot\inf\setupapi.upgrade.log"; 'LogFilter' = '*.*'; 'Recurse' = $false}
#File: $LogPaths += @{'LogName' = 'WindowsMoSetupBlueBox'; 'LogPath' = "$env:SystemRoot\Logs\MoSetup\BlueBox.log"; 'LogFilter' = '*.*'; 'Recurse' = $false}

#Add CCMSetup log path to list of log paths
$LogPaths += @{'LogName' = 'CCMSetup'; 'LogPath' = "$env:WinDir\ccmsetup\logs"; 'LogFilter' = '*.log'; 'Recurse' = $false}

#Add ConfigMgr Client log path to list of log paths
try {
	$CCMclientLogsPath = Get-ItemProperty "HKLM:\Software\Microsoft\CCM\Logging\@global" -ErrorAction Stop | Select-Object -ExpandProperty LogDirectory
} catch {
	try {
		$CCMclientLogsPath = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\SMS\Client\Configuration\Client Properties" -ErrorAction Stop | Select-Object -ExpandProperty 'Local SMS Path'
	} catch {
		try {
			$CCMclientLogsPath = Split-Path -Path $(Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\services\CcmExec" -ErrorAction Stop | Select-Object -ExpandProperty ImagePath) -Parent
		} catch {
			$CCMclientLogsPath = "$env:WinDir\CCM"
		}
	}
	If ($CCMclientLogsPath -like '"*') {
		#"`"*"
		#handle case where a double-quote starts the variable and optionally ends it
		$CCMclientLogsPath = $CCMclientLogsPath.Split('"')[1]
	}
	$CCMclientLogsPath = "$CCMclientLogsPath\Logs"
}
Write-LogMessage -Message "CCMclientLogsPath is $CCMclientLogsPath"
$LogPaths += @{'LogName' = 'CCMClient'; 'LogPath' = "$CCMclientLogsPath"; 'LogFilter' = '*.lo*'; 'Recurse' = $true}

#Verify the ConfigMgr Client logs folder is accessible
If (-not(Test-Path -Path "$CCMclientLogsPath" -PathType Container)) {
	Write-LogMessage -Message "Failed to access path [$CCMclientLogsPath]." -Type Error
	Write-OutputMessage -Message "Failed to access path [$CCMclientLogsPath]."
	Stop-Script -ReturnCode -2
}

#Copy files to the Temporary folder
$LogPaths | ForEach-Object {
	Copy-ItemsEx -Source "$($_.LogPath)" -Destination "$(Join-Path -Path $TempPath -ChildPath $_.LogName)" -Filter $($_.LogFilter) -Recurse $_.Recurse
}

#get MS System Information ... DISABLED due to long execution time
#Write-LogMessage -Message "Running MSInfo32.exe"
#$rc = Start-Process -Wait -NoNewWindow -RedirectStandardOutput "$TempPath\MSInfo32.StdOut" -RedirectStandardError "$TempPath\MSInfo32.StdErr" -FilePath "$env:WinDir\System32\msinfo32.exe" -ArgumentList '/report', "$TempPath\MSInfo32.txt" # -Wait


#Compress the temporary folder
Write-LogMessage -Message "Compressing folder [$TempPath] to [$CCMclientLogsPath\$localArchiveFileName]"
$CompressArchiveSuccess = $false
If ($PSVersionTable.PSVersion.Major -ge 5) {
	try {
		Compress-Archive -Path "$TempPath\*" -DestinationPath "$CCMclientLogsPath\$localArchiveFileName" -CompressionLevel Optimal -Force
		$CompressArchiveSuccess = $true
	} catch { }
} ElseIf ($PSVersionTable.PSVersion.Major -ge 3) {
	try {
		Add-Type -Assembly 'System.IO.Compression.FileSystem'
		[System.IO.Compression.ZipFile]::CreateFromDirectory($Path, $File, $([System.IO.Compression.CompressionLevel]::Optimal), $false)
		$CompressArchiveSuccess = $true
	} catch { }
} Else {
	try {
		Compress-ZipFile -FileOrDirectoryPathToAddToZipFile "$TempPath\*" -ZipFilePath "$CCMclientLogsPath\$localArchiveFileName" -OverwriteWithoutPrompting
		$CompressArchiveSuccess = $true
	} catch { }
}

#Remove the temporary folders and files
Remove-Item -Path "$TempPath" -Recurse -Force -ErrorAction SilentlyContinue
Write-LogMessage -Message "Removed temporary folder [$TempPath]"
If ($CompressArchiveSuccess -eq $true) {
	Write-LogMessage -Message "Compressed folder [$TempPath] to [$CCMclientLogsPath\$localArchiveFileName]"
} Else {
	Write-LogMessage -Message "Failed to compress folder [$TempPath] to [$CCMclientLogsPath\$localArchiveFileName]" -Type Error -Console
	Write-OutputMessage -Message "Failed to upload file $remoteArchiveFileName.  Failed to compress [$TempPath]"
	Remove-Archive
	Stop-Script -ReturnCode -3
}

#attempt to set the server share to the client's Management Point
If ([string]::IsNullOrEmpty($LogServer)) {
	Write-LogMessage -Message "Setting the server upload path to the ConfigMgr Management Point"
	try {
		#$ConfigMgrMP = (Get-CIMinstance -Namespace 'root\ccm\LocationServices' -ClassName sms_mpinformation).MP[0]
		$LogServer = (Get-WmiObject -Namespace 'root\CCM\LocationServices' -Class 'SMS_MPInformation' -Property 'MP').MP[0]
	} catch {
		Write-LogMessage -Message "Failed to retrieve ConfigMgr Management Point [$LogServer]." -Type Error -Console
		Write-OutputMessage -Message "Failed to upload file [$remoteArchiveFileName].  Failed to retrieve ConfigMgr Management Point [$LogServer]"
		Remove-Archive
		Stop-Script -ReturnCode -8
	}
}

#verify the server share is online
If (-not(Test-Connection -ComputerName $LogServer -Quiet -Count 1)) {
	#TODO: test HTTP connectivity on ConfigMgr's port.  Ensure it works with PoSH 2.0
	Write-LogMessage -Message "Failed to communicate with log server [$LogServer]." -Type Error -Console
	Write-OutputMessage -Message "Failed to upload file [$remoteArchiveFileName].  Test-Connection failed to [$LogServer]"
	Remove-Archive
	Stop-Script -ReturnCode -9
}

#send archive to server share
Write-LogMessage -Message "Copying [$CCMclientLogsPath\$localArchiveFileName] to [$LogServerLogsUNCPath\$remoteArchiveFileName]"
try {
	#Copy the archive file to the file share using SMB
	If (-not(Test-Path -Path "$LogServerLogsUNCPath" -PathType Container)) {
		New-Item -Path "$LogServerLogsUNCPath" -Type Directory -Force | Out-Null
		Write-LogMessage -Message "Created path [$LogServerLogsUNCPath]"
	}
	Copy-Item -Path "$CCMclientLogsPath\$localArchiveFileName" -Destination "$LogServerLogsUNCPath\$remoteArchiveFileName" -Force
	Write-LogMessage -Message "Copied [$CCMclientLogsPath\$localArchiveFileName] to [$LogServerLogsUNCPath\$remoteArchiveFileName]"
	Write-OutputMessage -Message "Saved file $LogServerLogsUNCPath\$remoteArchiveFileName"
} catch {
	Write-OutputMessage -Message "Failed to copy [$CCMclientLogsPath\$localArchiveFileName] to [$LogServerLogsUNCPath\$remoteArchiveFileName]"
	Write-LogMessage -Message "Failed to copy [$CCMclientLogsPath\$localArchiveFileName] to [$LogServerLogsUNCPath\$remoteArchiveFileName]"
	#Write-LogMessage -Message "Uploading [$CCMclientLogsPath\$localArchiveFileName] to [$LogServerLogsURIPath/$remoteArchiveFileNam]"
	##Copy the archive file to the file share using BITS
	#try {
	#	Import-Module BitsTransfer -Force
	#	Start-BitsTransfer -Source "$CCMclientLogsPath\$localArchiveFileName" -Destination "$LogServerLogsURIPath/$remoteArchiveFileName" -TransferType Upload
	#	Write-LogMessage -Message "Uploaded [$CCMclientLogsPath\$localArchiveFileName] to [$LogServerLogsURIPath/$remoteArchiveFileName]"
	#	Write-OutputMessage -Message  "Uploaded file $LogServerLogsURIPath/$remoteArchiveFileName"
	#} catch {
	#	Write-LogMessage -Message "Failed to upload [$CCMclientLogsPath\$localArchiveFileName] to [$LogServerLogsURIPath/$remoteArchiveFileName]"
	#	Write-OutputMessage -Message "Failed to upload file $remoteArchiveFileName to [$LogServerLogsUNCPath] or [$LogServerLogsURIPath]"
	#	Remove-Archive
	#	Stop-Script -ReturnCode -1
	#}
	Remove-Archive
	Stop-Script -ReturnCode 2
}
Stop-Script -ReturnCode 0