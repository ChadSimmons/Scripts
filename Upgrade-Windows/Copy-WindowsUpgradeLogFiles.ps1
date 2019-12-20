<#
Sample script to copy logs from a directory to a centralized backup location by KIETH GARNER
Path can only contain folders under c:\
Future: Move to shell.application zip functions for Windows 7 - Not this release, calls are asynchronous

.EXAMPLE
   PowerShell.exe -version 2.0 -Verbose -NoLogo -NoProfile -ExecutionPolicy Bypass -File "\\Server\g$\ConfigMgr Imports\WaaS-TS\GARYTOWN-WaaS-PreCache_files\WaaS_Scripts\CopyLogs\Copy-LogsToArchive.ps1" -TargetRoot "\\Server\Logs\Win10 Upgrade\1803 CompatScan" -LogID %ComputerName%
.EXAMPLE
   PowerShell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "\\Server\g$\ConfigMgr Imports\WaaS-TS\GARYTOWN-WaaS-PreCache_files\WaaS_Scripts\CopyLogs\Copy-LogsToArchive.ps1" -TargetRoot "\\Server\Logs\Win10 Upgrade\1803 Upgrade\Success" -LogID %ComputerName%
#>

[cmdletbinding()]
param(
	[string[]]$Path = @(
		"$env:SystemDrive\`$WINDOWS.~BT\Sources\Panther"
		"$env:SystemDrive\`$WINDOWS.~BT\Sources\Rollback"
		"$env:SystemRoot\Panther"
		"$env:SystemRoot\SysWOW64\PKG_LOGS"
		"$env:SystemRoot\CCM\Logs"
		<#
        "$env:SystemRoot\System32\winevt\Logs"
        "${env:CommonProgramFiles(x86)}\CheckPoint\Endpoint Security\Endpoint Common\Logs\cpda.log"
        "$env:SystemRoot\Logs\CBS\CBS.log"
        "$env:SystemRoot\inf\setupapi.upgrade.log"
        "$env:SystemRoot\Logs\MoSetup\BlueBox.log"
	#>
	),
	[string]$TargetRoot = '\\Server\Logs\Win10 Upgrade',
	[string]$LogID = $env:ComputerName,
	[string[]]$Exclude = @('*.exe', '*.wim', '*.dll', '*.ttf', '*.mui')
)

#region Prepare Target
Write-Verbose -Message 'Log Archive Tool  1.1'
$ArchiveID = [string]$($LogID + '_' + $([datetime]::now.Tostring('yyyyMMdd_HHmm')))
Write-Verbose -Message "ArchiveID is [$ArchiveID]"
Write-Verbose -Message "Creating Target folder [$TargetRoot]"
New-Item -ItemType Directory -Path $TargetRoot -Force -ErrorAction SilentlyContinue | out-null
#endregion

#region Create temporary Store
$TempPath = [System.IO.Path]::GetTempFileName()
Write-Verbose -Message "TempPath is [$TempPath]"
Remove-Item $TempPath
new-item -type directory -path $TempPath -force | out-null

foreach ( $Item in $Path ) {
	$TmpTarget = (join-path $TempPath ( split-path -NoQualifier $Item ))
	Write-Verbose -Message "Copy [$Item] to [$TmpTarget]"
	Copy-Item -Path $Item -Destination $TmpTarget -Force -Recurse -exclude $Exclude -ErrorAction SilentlyContinue
}

Write-Verbose -Message "PowerShell version: $($PSVersionTable.PSVersion.Major)"
If ($PSVersionTable.PSVersion.Major -eq 5) {
	Write-Verbose -Message 'PowerShell version 5 detected, compressing using PowerShell'
	try {
		Compress-Archive -path "$TempPath\*" -DestinationPath "$TargetRoot\$($ArchiveID).zip" -Force
	} catch {
		Write-Error "Failed to archive logs to [$TargetRoot\$($ArchiveID).zip]."
	}
} ElseIf ($PSVersionTable.PSVersion.Major -ge 3) {
	Write-Verbose -Message 'PowerShell version >=3 detected, compressing using .NET'
	try {
		Add-Type -Assembly 'System.IO.Compression.FileSystem'
		[System.IO.Compression.ZipFile]::CreateFromDirectory($TempPath, "$TargetRoot\$($ArchiveID).zip", $([System.IO.Compression.CompressionLevel]::Optimal), $false)
	} catch {
		Write-Error "Failed to archive logs to [$TargetRoot\$($ArchiveID).zip]."
	}
} Else {
	Write-Verbose -Message 'PowerShell version < 3 detected, copying files instead of compressing.'
	try {
		New-Item -ItemType Directory -Path "$TargetRoot\$ArchiveID" -Force -ErrorAction SilentlyContinue | out-null
		Copy-Item -Path "$TempPath\*" -Destination "$TargetRoot\$ArchiveID" -Force -Recurse -ErrorAction SilentlyContinue
	} catch {
		Write-Error "Failed to copy logs to destination folder [$TargetRoot\$ArchiveID]."
	}
}

Write-Verbose -Message "Removing Temp Path [$TempPath]"
Remove-Item $tempPath -Recurse -Force
#endregion

#region Metadata
<#
FUTURE - need to create an index folder with right permissions
$LogID | add-content -encoding Ascii -Path "$TargetRoot\Index\$((get-date -f 'd').replace('/','-')).txt"
#>
#endregion