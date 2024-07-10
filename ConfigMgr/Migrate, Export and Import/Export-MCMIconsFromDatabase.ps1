################################################################################################# #BOOKMARK: Script Help
#.SYNOPSIS
#	Export-MCMIconsFromDatabase.ps1
#	Export Application, Package, and Task Sequence ICONs as PNG files from a Configuration Manager database
#.DESCRIPTION
#
#   THIS CODE AND ANY RELATED INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED OR IMPLIED,
#   INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR PURPOSE.  We
#   grant You a nonexclusive, royalty-free right to use and modify, but not distribute, the code, provided that You agree:
#   (i) to retain Our name, logo, or trademarks referencing Us as the original provider of the code;
#   (ii) to indemnify, hold harmless, and defend Us and Our suppliers from and against any claims or lawsuits, including
#   attorney fees, that arise or result from the use of the Code.
#.PARAMETER Server
#   Specifies the DNS name, NetBIOS name or IP Address of the Microsoft Configuration Manager site database server
#.PARAMETER Database
#   Specifies the name of the Configuration Manager site database
#.PARAMETER Path
#   Specifies the full directory or folder path to export ICONS to
#.Parameter LogFile
#   Full folder directory path and file name for logging
#   Defaults to C:\Windows\Logs\<ScriptFileName>.log
#.EXAMPLE
#   Export-MCMIconsFromDatabase.ps1 -Path 'C:\Data\ConfigMgr Icons'
#.NOTES
#	based on https://www.checkyourlogs.net/export-icons-from-configmgr-database
#   Additional information about the function or script.
#   ========== Keywords =========================
#   Keywords: SCCM ConfigMgr Icons PNG logos
#   ========== Change Log History ===============
#   - 2024/07/09 by Chad@ChadsTech.net - Added Package and Task Sequence support.  Refactored code to standard PowerShell template
#   - 2020/01/14 by @ecabot - Émile Cabot | https://www.checkyourlogs.net/author/ecabot
#   ========== To Do / Proposed Changes =========
#   - #TODO: Add logging and additional error handling
########################################################################################################################
#region ############# Parameters and variable initialization ############################## #BOOKMARK: Script Parameters

#region ############# Parameters and variable initialization ############################## #BOOKMARK: Script Parameters
[CmdletBinding()] #(SupportsShouldProcess=$false, ConfirmImpact="Low")
Param (
	[Parameter(Mandatory = $false, HelpMessage = 'Configuration Manager database server')][string]$Server = 'ConfigMgrDb.contoso.com',
	[Parameter(Mandatory = $false, HelpMessage = 'Configuration Manager database name')][string]$Database = 'CM_PRI',
	[Parameter(Mandatory = $false, HelpMessage = 'Output path for icon/PNG storage')][Alias('Destination')][string]$Path = 'E:\Data\Icons',
	[Parameter(Mandatory = $false, HelpMessage = 'Full folder directory path and file name for logging')][Alias('Log')][string]$LogFile # Functions default this to CommonDocuments\Logs\... = $(Join-Path -Path $([System.Environment]::GetFolderPath('Personal')) -ChildPath 'Logs\Scripts.log')
)
$BufferSize = 8192
#endregion ########## Parameters and variable initialization ##########################################################>

If (-not(Test-Path -Path $Path -PathType Container -ErrorAction Stop)) {
	New-Item -ItemType Directory -Path $Path -Force -ErrorAction Stop
}

#endregion ########## Initialization ###################################################################################
#region ############# Main Script ############################################################### #BOOKMARK: Script Main

# T-SQL query for database embedded icons in Applications, Packages, and Task Sequences
# $Sql = 'SELECT Distinct([Icon]), [Title] FROM dbo.[CI_LocalizedCIClientProperties] where [Icon] is not null'

$sqlCommandText = "SELECT Distinct(Icon), 'App' [Type], Trim(' ' From (Publisher + ' ' + Title + ' ' + Version)) [ObjectFullName], Cast(CI_ID as varchar) [ContentID]
FROM CI_LocalizedCIClientProperties where Icon is not null
UNION
SELECT Distinct(P.Icon), 'Pkg' [Type], Trim(' ' FROM (P.Manufacturer + ' ' + P.Name + ' ' + P.Version)) [ObjectFullName], PkgID [ContentID]
FROM SMSPackages_G P inner join v_Package T on P.PkgId = T.PackageID where P.Icon is not null and P.PkgId NOT IN (Select PackageID from v_TaskSequencePackage)
UNION
SELECT Distinct(P.Icon), 'TS' [Type], P.Name [ObjectFullName], PkgID [ContentID]
FROM SMSPackages_G P inner join v_TaskSequencePackage T on P.PkgId = T.PackageID where P.Icon is not null
order by ContentID"

$sqlConnection = New-Object -TypeName System.Data.SqlClient.SqlConnection
$sqlConnection.ConnectionString = "Data Source=$Server; Integrated Security=True; Initial Catalog=$Database"
$sqlConnection.Open()

$sqlCommand = New-Object -TypeName System.Data.SqlClient.SqlCommand -ArgumentList $sqlCommandText, $sqlConnection
$sqlExecutionReader = $sqlCommand.ExecuteReader()

$BinaryWriterOutput = [array]::CreateInstance('Byte', $BufferSize)

$iCount = 0
While ($sqlExecutionReader.Read()) {
	$iCount++
	try {
		$start = $sqlExecutionReader.GetString(2) #if this is null the try block will error

		# Attempt to get the Application, Package, or Task Sequence name in a variable
		$ObjectName = $(try { $sqlExecutionReader.GetString(2) } catch { $sqlExecutionReader.GegString(3) })
		# Format the file name as [ObjectType] - [ObjectName].png
		$FileName = $($sqlExecutionReader.GetString(1) + ' - ' + $ObjectName + '.png')
		# replace any invalid file name characters with an underscore
		$FileName = $FileName.Split([IO.Path]::GetInvalidFileNameChars()) -join '_'
		Write-Output ("$iCount : Exporting Objects from FILESTREAM container to [{0}] to [$FileName]" -f $ObjectName)
		# Write to FileStream object at the specified full path name (creates an empty file)
		$FileStream = New-Object -TypeName System.IO.FileStream -ArgumentList ($(Join-Path -Path $Path -ChildPath $FileName)), Create, Write;
		$BinaryWriter = New-Object -TypeName System.IO.BinaryWriter -ArgumentList $FileStream
		$start = 0
		# Read first byte stream
		$BytesReceived = $sqlExecutionReader.GetBytes(0, $start, $BinaryWriterOutput, 0, $BufferSize - 1)
		While ($BytesReceived -gt 0) {
			$BinaryWriter.Write($BinaryWriterOutput, 0, $BytesReceived)
			$BinaryWriter.Flush()
			$start += $BytesReceived
			#Read next byte stream
			$BytesReceived = $sqlExecutionReader.GetBytes(0, $start, $BinaryWriterOutput, 0, $BufferSize - 1)
		}
		$BinaryWriter.Close()
		$FileStream.Close()
	} catch {
		Write-Output $_.Exception.Message
	} finally {
		$FileStream.Dispose()
	}
}

#endregion ########## Main Script ######################################################################################
#region ############# Finalization ########################################################## #BOOKMARK: Script Finalize
$sqlExecutionReader.Close()
$sqlCommand.Dispose()
$sqlConnection.Close()
Write-Output 'Finished'
#endregion ########## Finalization ####################################################################################>