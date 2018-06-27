#Requires -Version 2.0
#.Synopsis
#   Upload-ConfigMgrClientLogs.ps1
#   Compress ConfigMgr setup logs, client logs, and custom logs and copy to the specified Server or the associated Management Point
#.Notes
#	This script is maintained at https://github.com/ChadSimmons/Scripts/ConfigMgr
#	Additional information about the function or script.
#   - This script should be compatible with PowerShell 2.0 to support Windows 7 default version as well as older operating systems
#   - This script can be deployed as a ConfigMgr Package, Application, Compliance Setting, or Script
#	========== Change Log History ==========
#	- 2018/06/14 by Chad.Simmons@CatapultSystems.com - Added additional inventory including from https://www.windowsmanagementexperts.com/configmgr-run-script-collect-logs/configmgr-run-script-collect-logs.htm
#	- 2018/06/13 by Chad.Simmons@CatapultSystems.com - Added function to compress files with PowerShell 2.0 from http://blog.danskingdom.com/module-to-synchronously-zip-and-unzip-using-powershell-2-0
#	- 2017/10/30 by Chad.Simmons@CatapultSystems.com - Created
#	- 2017/10/30 by Chad@ChadsTech.net - Created
#	=== To Do / Proposed Changes ===
#	- TODO: Detect if running as a ConfigMgr Script and format output as JSON
#	========== Additional References and Reading ==========
#   - Based on https://blogs.technet.microsoft.com/setprice/2017/08/16/automating-collection-of-config-mgr-client-logs
#   - Based on http://ccmexec.com/2017/10/powershell-script-to-collect-sccm-log-files-from-clients-using-run-script/
#   - Based on https://www.windowsmanagementexperts.com/configmgr-run-script-collect-logs/configmgr-run-script-collect-logs.htm
#   -             https://blogs.msdn.microsoft.com/rkramesh/2016/09/19/sccm-client-log-collection-for-troubleshooting/

[CmdletBinding(SupportsShouldProcess=$False,ConfirmImpact='None')] 
Param ( [switch]$DeleteLocalArchive, [switch]$SuppressConsoleOutput )
#Set Variables
$LogServer = '' #if blank, the client Management Point will be used
$SharePath = 'ConfigMgrClientLogs/ConfigMgrClient'
If (-not($PSBoundParameters.ContainsKey('DeleteLocalArchive')) { $DeleteLocalArchive = $false }
#If Running as a ConfigMgr Script, set SuppressConsoleOutput to True so the only thing logged is the final status
$SuppressConsoleOutput = $true

$LogPaths = @() #create a hashtable of Log Names and Paths.  The ConfigMgr client logs and ccmsetup logs are added to the list later
$LogPaths += @{'LogName' = 'SMSTSRootLogs'; 'LogPath' = "$env:SystemDrive\_SMSTaskSequence\Logs"; 'LogFilter' = '*.*'; 'Recurse' = $true}
$LogPaths += @{'LogName' = 'SMSTSTempLogs'; 'LogPath' = "$env:WinDir\Temp\SMSTS"; 'LogFilter' = '*.*'; 'Recurse' = $true}
$LogPaths += @{'LogName' = 'Panther'; 'LogPath' = "$env:WinDir\Panther"; 'LogFilter' = '*.*'; 'Recurse' = $true}
$LogPaths += @{'LogName' = 'PantherWindowsBT'; 'LogPath' = "$env:SystemDrive\$WINDOWS.~BT\Panther"; 'LogFilter' = '*.*'; 'Recurse' = $true}
$LogPaths += @{'LogName' = 'WinDirLogs'; 'LogPath' = "$env:WinDir\Logs"; 'LogFilter' = '*.*'; 'Recurse' = $false}
$LogPaths += @{'LogName' = 'WinDirLogsSoftware'; 'LogPath' = "$env:WinDir\Logs\Software"; 'LogFilter' = '*.*'; 'Recurse' = $true}

#region    ######################### Functions #################################
################################################################################
Function Get-ScriptPath {
	#.Synopsis
	#   Get the folder of the script file
	#.Notes
	#   See snippet Get-ScriptPath.ps1 for excrutiating details and alternatives
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
	Return $script:ScriptPath
}
Function Get-ScriptName {
	#.Synopsis
	#   Get the name of the script file
	#.Notes
	#   See snippet Get-ScriptPath.ps1 for excrutiating details and alternatives
	If ($psISE) {
		$script:ScriptName = Split-Path $psISE.CurrentFile.FullPath -Leaf #this works in psISE and psISE functions
	} else {
		$script:ScriptName = ((Get-Variable MyInvocation -Scope 1 -ErrorAction SilentlyContinue).Value).MyCommand.Name
	}
	$script:ScriptBaseName = [System.IO.Path]::GetFileNameWithoutExtension($script:ScriptName)
	Write-Verbose "Function Get-ScriptName: ScriptName is $($script:ScriptName)"
	Write-Verbose "Function Get-ScriptName: ScriptBaseName is $($script:ScriptBaseName)"
	return $script:ScriptName
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
	If ($Component -eq $null) {$Component = ' '} #Must not be null
	try {
		"<![LOG[$Message]LOG]!><time=`"$(Get-Date -Format "HH:mm:ss.ffffff")`" date=`"$(Get-Date -Format "MM-dd-yyyy")`" component=`"$Component`" context=`"`" type=`"$Type`" thread=`"`" file=`"`">" | Out-File -Append -Encoding UTF8 -FilePath $LogFile
	} catch {
		Write-Error "Failed to write to the log file '$LogFile'"
	}
	If ($Console -eq $true -and $SuppressConsoleOutput -ne $true) { Write-Output $Message } #write to console if enabled
}; Set-Alias -Name 'Write-CMEvent' -Value 'Write-LogMessage' -Description 'Log a message in CMTrace format'
Function Start-Script ($LogFile) {
	$script:ScriptStartTime = Get-Date
	$script:ScriptPath = Get-ScriptPath
	$script:ScriptName = Get-ScriptName

	#If the LogFile is undefined set to \Windows\Logs\<ScriptName>log #<ScriptPath>\<ScriptName>.log
	If ([string]::IsNullOrEmpty($LogFile)) {
		$script:LogFile = "$env:WinDir\Logs\$([System.IO.Path]::GetFileNameWithoutExtension($script:ScriptName)).log"
		#$script:LogFile = "$script:ScriptPath\$([System.IO.Path]::GetFileNameWithoutExtension($script:ScriptName)).log"
	} else { $script:LogFile = $LogFile }

	#If the LogFile folder does not exist, create the folder
	Set-Variable -Name LogPath -Value $(Split-Path -Path $script:LogFile -Parent) -Description 'The folder/directory containing the log file' -Scope Script
	If (-not(Test-Path $LogPath)) { New-Item -Path $LogPath -ItemType Directory -Force}

	Write-LogMessage -Message "==================== SCRIPT START ====================" -Component $script:ScriptName
#	Write-LogMessage -Message "Logging to $script:LogFile" -Console
}
Function Stop-Script ($ReturnCode) {
	Write-LogMessage -Message "Exiting with return code $ReturnCode"
	$ScriptEndTime = Get-Date
	$ScriptTimeSpan = New-TimeSpan -Start $script:ScriptStartTime -end $ScriptEndTime #New-TimeSpan -seconds $(($(Get-Date)-$StartTime).TotalSeconds)
	Write-LogMessage -Message "Script Completed in $([math]::Round($ScriptTimeSpan.TotalSeconds)) seconds, started at $(Get-Date $script:ScriptStartTime -Format 'yyyy/MM/dd hh:mm:ss'), and ended at $(Get-Date $ScriptEndTime -Format 'yyyy/MM/dd hh:mm:ss')"
	Write-LogMessage -Message "==================== SCRIPT COMPLETE ====================" -Component $script:ScriptName
	Exit $ReturnCode
}
Function Remove-Archive {
	#Delete the local archive file
	If ($DeleteLocalArchive -eq $true) {
		Remove-Item -Path "$CCMclientLogsPath\$localArchiveFileName" -ErrorAction SilentlyContinue
		Write-LogMessage -Message "Deleted '$CCMclientLogsPath\$localArchiveFileName'"
	}
}
Function GetNumberOfItemsInZipFileItems($shellItems) {
	# Recursive function to calculate the total number of files and directories in the Zip file.
	[int]$totalItems = $shellItems.Count
	foreach ($shellItem in $shellItems)
	{
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
	if ($itemToCopyShell -eq $null -or !$itemToCopyShell.IsFolder)
	{
		$parentInZipFileShell.MoveHere($pathOfItemToCopy)
		
		# Wait for the file to be moved before continuing, to avoid erros about the zip file being locked or a file not being found.
		while (Test-Path -Path $pathOfItemToCopy)
		{ Start-Sleep -Milliseconds 10 }
	}
	# Else this is a directory that already exists in the Zip file, so we need to traverse it and copy each file/directory within it.
	else
	{
		# Copy each file/directory in the directory to the Zip file.
		foreach ($item in (Get-ChildItem -Path $pathOfItemToCopy -Force))
		{
			MoveDirectoryIntoZipFile -parentInZipFileShell $itemToCopyShell -pathOfItemToCopy $item.FullName
		}
	}
}
Function MoveFilesOutOfZipFileItems($shellItems, $directoryToMoveFilesToShell, $fileNamePrefix) {
	# Recursive function to move all of the files that start with the File Name Prefix to the Directory To Move Files To.
	# Loop through every item in the file/directory.
	foreach ($shellItem in $shellItems)
	{
		# If this is a directory, recursively call this function to iterate over all files/directories within it.
		if ($shellItem.IsFolder)
		{ 
			$totalItems += MoveFilesOutOfZipFileItems -shellItems $shellItem.GetFolder.Items() -directoryToMoveFilesTo $directoryToMoveFilesToShell -fileNameToMatch $fileNameToMatch
		}
		# Else this is a file.
		else
		{
			# If this file name starts with the File Name Prefix, move it to the specified directory.
			if ($shellItem.Name.StartsWith($fileNamePrefix))
			{
				$directoryToMoveFilesToShell.MoveHere($shellItem)
			}
		}			
	}
}
Function Compress-ZipFile {
	[CmdletBinding()]
	param (
		[parameter(Position=1,Mandatory=$true)]
		[ValidateScript({Test-Path -Path $_})]
		[string]$FileOrDirectoryPathToAddToZipFile, 
	
		[parameter(Position=2,Mandatory=$false)]
		[string]$ZipFilePath,
		
		[Alias("Force")]
		[switch]$OverwriteWithoutPrompting
	)
	
	BEGIN { 
        Write-Verbose "Starting Function Compress-ZipFile -FileOrDirectoryPathToAddToZipFile $FileOrDirectoryPathToAddToZipFile -ZipFilePath $ZipFilePath -OverwriteWithoutPrompting $OverwriteWithoutPrompting..."
    }
	END {
        Write-Verbose "Completed Function Compress-ZipFile"
     }
	PROCESS {
		# If a Zip File Path was not given, create one in the same directory as the file/directory being added to the zip file, with the same name as the file/directory.
		if ($ZipFilePath -eq $null -or $ZipFilePath.Trim() -eq [string]::Empty) { $ZipFilePath = Join-Path -Path $FileOrDirectoryPathToAddToZipFile -ChildPath '.zip' }
		
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
		$shell = New-Object -ComObject Shell.Application
		$zipShell = $shell.NameSpace($ZipFilePath)

		# We will want to check if we can do a simple copy operation into the Zip file or not. Assume that we can't to start with.
		# We can if the file/directory does not exist in the Zip file already, or it is a file and the user wants to be prompted on conflicts.
		$canPerformSimpleCopyIntoZipFile = $false

		# If the file/directory does not already exist in the Zip file, or it does exist, but it is a file and the user wants to be prompted on conflicts, then we can perform a simple copy into the Zip file.
		$fileOrDirectoryInZipFileShell = $zipShell.ParseName($fileOrDirectoryNameToAddToZipFile)
		$itemToAddToZipIsAFileAndUserWantsToBePromptedOnConflicts = ($itemToAddToZipIsAFile -and !$OverwriteWithoutPrompting)
		if ($fileOrDirectoryInZipFileShell -eq $null -or $itemToAddToZipIsAFileAndUserWantsToBePromptedOnConflicts) {
			$canPerformSimpleCopyIntoZipFile = $true
		}
		
		# If we can perform a simple copy operation to get the file/directory into the Zip file.
		if ($canPerformSimpleCopyIntoZipFile) {
			# Start copying the file/directory into the Zip file since there won't be any conflicts. This is an asynchronous operation.
			$zipShell.CopyHere($FileOrDirectoryPathToAddToZipFile)	# Copy Flags are ignored when copying files into a zip file, so can't use them like we did with the Expand-ZipFile function.
			
			# The Copy operation is asynchronous, so wait until it is complete before continuing.
			# Wait until we can see that the file/directory has been created.
			while ($zipShell.ParseName($fileOrDirectoryNameToAddToZipFile) -eq $null)
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
				$emptyDirectories = Get-ChildItem -Path $fileOrDirectoryPathInTempDirectory -Recurse -Force -Directory | Where-Object { (Get-ChildItem -Path $_ -Force) -eq $null }
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
			} while ($files -ne $null)
			
			# If there are dummy files that need to be moved out of the Zip file.
			if ($numberOfDummyFilesCreated -gt 0) {
				# Move all of the dummy files out of the supposed-to-be empty directories in the Zip file.
				MoveFilesOutOfZipFileItems -shellItems $zipShell.items() -directoryToMoveFilesToShell $tempDirectoryShell -fileNamePrefix $dummyFileNamePrefix
				
				# The Move operation is asynchronous, so wait until it is complete before continuing.
				# Sleep until all of the dummy files have been moved out of the zip file.
				do {
					Start-Sleep -Milliseconds 100
					[Object[]]$files = Get-ChildItem -Path $tempDirectoryPath -Force -Recurse | Where-Object { !$_.PSIsContainer -and $_.Name.StartsWith($dummyFileNamePrefix) }
				} while ($files -eq $null -or $files.Count -lt $numberOfDummyFilesCreated)
			}
			# Delete the temp directory that we created.
			Remove-Item -Path $tempDirectoryPath -Force -Recurse > $null
		}
	}
}
#region   from https://blogs.msdn.microsoft.com/rkramesh/2016/09/19/sccm-client-log-collection-for-troubleshooting
Function LogInfo ($FilePath = $CustomInventoryFile,$message) {
	Add-Content -Path "$CustomInventoryFile" -Value "$message`n"
}
Function GatherLogs(){
  # Gather logs
  # Collect the IPConfig /All
  LogInfo -Message "`t - Collecting : IPConfig"
  $colItems = Get-WmiObject -class "Win32_NetworkAdapterConfiguration" -computername $ClientHostname | Where {$_.IPEnabled -Match "True"}
  foreach ($objItem in $colItems) {      
       LogInfo -Message "`t `t `t `t " + $objItem.Description)
       LogInfo -Message "`t `t `t `t `t `t `t `t `t `t `t Physical Address. . . . . . . . . : " + $objItem.MACAddress
       LogInfo -Message "`t `t `t `t `t `t `t `t `t `t `t IPv4v6 Address. . . . . . . . . . : " + $objItem.IPAddress
       LogInfo -Message "`t `t `t `t `t `t `t `t `t `t `t Subnet Mask . . . . . . . . . . . : " + $objItem.IPSubnet
       LogInfo -Message "`t `t `t `t `t `t `t `t `t `t `t IPEnabled . . . . . . . . . . . . : " + $objItem.IPEnabled
       LogInfo -Message "`t `t `t `t `t `t `t `t `t `t `t DNS Servers . . . . . . . . . . . : " + $objItem.DNSServerSearchOrder
       LogInfo -Message "`t `t `t `t `t `t `t `t `t `t `t DHCP Server . . . . . . . . . . . : " + $objItem.DHCPServer
       LogInfo -Message "`t `t `t `t `t `t `t `t `t `t `t DNS Suffix Search List. . . . . . : " + $objItem.DNSDomainSuffixSearchOrder
    }

  # Collect the CCMCache folder info
  $CCMCacheFolder = "C:\Windows\ccmcache"
  $colItems = (Get-ChildItem $CCMCacheFolder -recurse | Where-Object {$_.PSIsContainer -eq $True} | Sort-Object)
  $CCMCachSize=0
  foreach ($i in $colItems) {
        $subFolderItems = (Get-ChildItem $i.FullName | Measure-Object -property length -sum)
        $CCMCachSize=$CCMCachSize+"{0:N2}" -f ($subFolderItems.sum / 1MB)
  }
  
  $GetCCMCachSize = "{0:N2}" -f ($CCMCachSize/1024)
  $CCMCache = Get-ChildItem -Path $CCMCacheFolder -Recurse | Out-File ($FolderPath.FullName + "\CCMCache - "+ $GetCCMCachSize +" GB.txt")
  LogInfo -Message "`t - Collecting : CCMCache Info"
  LogInfo -Message "`t `t `t `t `t `t `t `t `t `t `t CCMCache folder size is "+ $GetCCMCachSize +" GB"
  If ($GetCCMCachSize -gt 5) {LogInfo -Message "`t `t `t `t `t `t `t `t `t `t `t Warning: CCMCache folder size is more than 5 GB" }

  ## Applications installed
  #Write-Host "`t - Collecting : Installed Applications"
  #$InstalledApp = Wmic Product | Format-Table -AutoSize | Out-String -Width 1024 | Out-File ($FolderPath.FullName + "\SoftwareInstalled.txt")
  #LogInfo ("`t - Collecting : Installed Applications")        
}
#endregion from https://blogs.msdn.microsoft.com/rkramesh/2016/09/19/sccm-client-log-collection-for-troubleshooting

################################################################################
#endregion ######################### Functions #################################

#region    ######################### Main Script ###############################
Start-Script -LogFile "$env:WinDir\Logs\Upload-ConfigMgrClientLogs.log"
$TempPath = "$env:Temp\$([System.Guid]::NewGuid().ToString())"
$remoteArchiveFileName = "$($env:ComputerName).$(Get-Date -format 'yyyyMMdd_HHmm').zip"
$localArchiveFileName = "ConfigMgrClientLogArchive.$(Get-Date -format 'yyyyMMdd_HHmm').zip"
$ReturnCode = 0

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
	If ($CCMclientLogsPath -like '"*') { #"`"*"
		#handle case where a double-quote starts the variable and optionally ends it
      $CCMclientLogsPath = $CCMclientLogsPath.Split('"')[1]
    }
   $CCMclientLogsPath = "$CCMclientLogsPath\Logs"
}
Write-LogMessage -Message "CCMclientLogsPath is $CCMclientLogsPath"
$LogPaths += @{'LogName' = 'CCMClient'; 'LogPath' = "$CCMclientLogsPath"; 'LogFilter' = '*.lo*'; 'Recurse' = $false}

#Verify the ConfigMgr Client logs folder is accessible
If (-not(Test-Path -Path "$CCMclientLogsPath")) {
	Write-LogMessage -Message "Failed to access path '$CCMclientLogsPath'." -Type Error -Console
	Stop-Script -ReturnCode -2
}
#Create the Temporary folder
If (-not(Test-Path -Path "$TempPath")) {
	try {
		New-Item -itemType Directory -Path "$TempPath" -ErrorAction Stop | Out-Null
		Write-LogMessage -Message "Created path '$TempPath'."
	} catch {
		Write-LogMessage -Message "Failed to create path '$TempPath'." -Type Error -Console
		Stop-Script -ReturnCode -2
	}
}
#Copy files to the Temporary folder
$LogPaths | ForEach-Object {
	$LogPath = $_.LogPath
	If (Test-Path -Path $LogPath) {
		$LogName = $_.LogName
		$LogFilter = $_.LogFilter
		try {
			If (-not(Test-Path -Path "$TempPath\$LogName")) {
				New-Item -itemType Directory -Path "$TempPath" -name "$LogName" -ErrorAction Stop | Out-Null
				Write-LogMessage -Message "Created path '$TempPath\$LogName'."
			}
			If ($_.Recurse) {
				Copy-Item -Path "$LogPath\$LogFilter" -Destination "$TempPath\$LogName" -Force -ErrorAction Stop -Recurse
			} else {
				Copy-Item -Path "$LogPath\$LogFilter" -Destination "$TempPath\$LogName" -Force -ErrorAction Stop
			}
			Write-LogMessage -Message "Copied $LogFilter from '$LogPath' to '$TempPath\$LogName'."
		} catch {
			Write-LogMessage -Message "Failed to copy $LogFilter from '$LogPath' to '$TempPath\$LogName'." -Type Warn -Console
		}
	} else {
		Write-LogMessage -Message "The path '$LogPath' does not exist or is inaccessible." -Type Warn -Console
	}
}

#get System Informaiton
msinfo32.exe /report "$TempPath\MSInfo32.txt"

#region    from https://blogs.msdn.microsoft.com/rkramesh/2016/09/19/sccm-client-log-collection-for-troubleshooting
Set-Variable -Name CustomInventoryFile -Scope Script -Value "$TempPath\CustomInventory.txt"
GatherLogs # Gather logs and other information
# MS Patches installed
$InstalledUpdates = WMIC QFE GET | Format-Table -AutoSize | Out-String -Width 1024 | Out-File "$TempPath\SoftwareUpdate.txt"
#endregion from https://blogs.msdn.microsoft.com/rkramesh/2016/09/19/sccm-client-log-collection-for-troubleshooting


#region    from https://www.windowsmanagementexperts.com/configmgr-run-script-collect-logs/configmgr-run-script-collect-logs.htm
# get Windows Update log
if ((Get-WmiObject -class Win32_OperatingSystem).version -lt 9) {
	Copy-Item -Path "$env:WinDir\WindowsUpdate.log" -Destination "$TempPath\WindowsUpdate.log"
} else { 
	Get-WindowsUpdateLog -LogPath "$TempPath\WindowsUpdate.log"
}

# run gpresult
GPResult.exe /scope computer /h $TempPath\GPResult.html

# export event logs
$eventLogsPath = "$TempPath\EventLogs"
New-Item -Path $eventLogsPath -ItemType directory -Force
wevtutil.exe epl System "$eventLogsPath\system.evtx"
wevtutil.exe epl Application "$eventLogsPath\application.evtx"
wevtutil.exe epl Microsoft-Windows-MBAM/Admin "$eventLogsPath\mbam-admin.evtx"
wevtutil.exe epl Microsoft-Windows-MBAM/Operational "$eventLogsPath\mbam-operational.evtx"
wevtutil.exe epl "Microsoft-Windows-BitLocker/BitLocker Management" "$eventLogsPath\bitlocker-mgmt.evtx"
wevtutil.exe epl "Microsoft-Windows-BitLocker/BitLocker Operational" "$eventLogsPath\bitlocker-operational.evtx"
wevtutil.exe epl "Key Management Service" "$eventLogsPath\kms.evtx"
wevtutil.exe epl "Microsoft-Windows-Windows Defender/Operational" "$eventLogsPath\defender-operational.evtx"
#endregion from https://www.windowsmanagementexperts.com/configmgr-run-script-collect-logs/configmgr-run-script-collect-logs.htm


#Compress the tempoary folder
try {
    #This method requires PowerShell 2.0
    Compress-ZipFile -FileOrDirectoryPathToAddToZipFile "$TempPath" -ZipFilePath "$CCMclientLogsPath\$localArchiveFileName" -OverwriteWithoutPrompting
 
    #This method requires PowerShell 3.0
    #Add-Type -Assembly System.IO.Compression.FileSystem
	#[System.IO.Compression.ZipFile]::CreateFromDirectory("$TempPath", "$CCMclientLogsPath\$localArchiveFileName", $([System.IO.Compression.CompressionLevel]::Optimal), $false)
    
    Write-LogMessage -Message "Compressed folder '$TempPath' to '$CCMclientLogsPath\$localArchiveFileName'"
	#Remove the temporary folders and files
	Remove-Item -Path "$TempPath" -Recurse -Force -ErrorAction SilentlyContinue
	Write-LogMessage -Message "Removed temporary folder '$TempPath'"
} catch {
	Write-LogMessage -Message "Failed to compress folder '$TempPath' to '$CCMclientLogsPath\$localArchiveFileName'" -Type Error -Console
	Remove-Item -Path "$TempPath" -Recurse -Force -ErrorAction SilentlyContinue
	Write-LogMessage -Message "Removed temporary folder '$TempPath'"
    Write-Output "Failed to upload file $remoteArchiveFileName.  Failed to compress '$TempPath'"
	Remove-Archive
	Stop-Script -ReturnCode -3
}

#attempt to set the server share to the client's Management Point
If ([string]::IsNullOrEmpty($LogServer)) {
	try {
		#$ConfigMgrMP = (Get-CIMinstance -Namespace 'root\ccm\LocationServices' -ClassName sms_mpinformation).MP[0]
		$LogServer = (Get-WmiObject -Namespace 'root\CCM\LocationServices' -Class 'SMS_MPInformation' -Property 'MP').MP[0]
	} catch {
		Write-LogMessage -Message "Failed to retrieve ConfigMgr Management Point '$LogServer'." -Type Error -Console
        Write-Output "Failed to upload file $remoteArchiveFileName.  Failed to retrieve ConfigMgr Management Point '$LogServer'"
		Remove-Archive
		Stop-Script -ReturnCode -8
	}
}
$LogServerLogsURIPath = "http://$LogServer/$SharePath"
$LogServerLogsUNCPath = "\\$LogServer\$SharePath"

#verify the server share is online
If (-not(Test-Connection -ComputerName $LogServer -Quiet -Count 1)) {
	#TODO: test HTTP connectivity on ConfigMgr's port.  Ensure it works with PoSH 2.0
	Write-LogMessage -Message "Failed to communicate with log server '$LogServer'." -Type Error -Console
    Write-Output "Failed to upload file $remoteArchiveFileName.  Test-Connection failed to $LogServer"
	Remove-Archive
	Stop-Script -ReturnCode -9
}

#send archive to server share
try {
	#Copy the archive file to the file share using SMB
	Copy-Item -Path "$CCMclientLogsPath\$localArchiveFileName" -Destination "$LogServerLogsUNCPath\$remoteArchiveFileName"
	Write-LogMessage -Message "Copied '$CCMclientLogsPath\$localArchiveFileName' to '$LogServerLogsUNCPath\$remoteArchiveFileName'" -Console
    Write-Output "Uploaded file $LogServerLogsUNCPath\$remoteArchiveFileName"
} catch {
	Write-LogMessage -Message "Failed to copy '$CCMclientLogsPath\$localArchiveFileName' to '$LogServerLogsUNCPath\$remoteArchiveFileName'"
	#Copy the archive file to the file share using BITS
	try {
		Import-Module BitsTransfer -Force
		Start-BitsTransfer -Source "$CCMclientLogsPath\$localArchiveFileName" -Destination "$LogServerLogsURIPath/$remoteArchiveFileName" -TransferType Upload
		Write-LogMessage -Message "Uploaded '$CCMclientLogsPath\$localArchiveFileName' to '$LogServerLogsURIPath/$remoteArchiveFileName'" -Console
        Write-Output "Uploaded file $LogServerLogsURIPath/$remoteArchiveFileName"
	} catch {
		Write-LogMessage -Message "Failed to upload '$CCMclientLogsPath\$localArchiveFileName' to '$LogServerLogsURIPath/$remoteArchiveFileName'" -Console
        Write-Output "Failed to upload file $remoteArchiveFileName to '$LogServerLogsUNCPath' or '$LogServerLogsURIPath'"
		Remove-Archive
		Stop-Script -ReturnCode -1
	}
}

Remove-Archive
Stop-Script -ReturnCode 0