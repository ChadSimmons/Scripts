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
#   Keywords: SCCM ConfigMgr Icon PNG logos
#   ========== Change Log History ===============
#   - YYYY/MM/DD by name@contoso.com - ~updated description~
#   - YYYY/MM/DD by name@contoso.com - created
#   ========== To Do / Proposed Changes =========
#   - #TODO: Add additional logging and error handling
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
$bufferSize = 8192
#endregion ########## Parameters and variable initialization ##########################################################>


#endregion ########## Initialization ###################################################################################
#region ############# Main Script ############################################################### #BOOKMARK: Script Main

# T-SQL query for database embedded icons in Applications, Packages, and Task Sequences
# $Sql = 'SELECT Distinct([Icon]), [Title] FROM dbo.[CI_LocalizedCIClientProperties] where [Icon] is not null'

$Sql = "SELECT Distinct(Icon), 'App' [Type], Trim(' ' From (Publisher + ' ' + Title + ' ' + Version)) [ObjectFullName], Cast(CI_ID as varchar) [ContentID]
FROM CI_LocalizedCIClientProperties where Icon is not null
UNION
SELECT Distinct(P.Icon), 'Pkg' [Type], Trim(' ' FROM (P.Manufacturer + ' ' + P.Name + ' ' + P.Version)) [ObjectFullName], PkgID [ContentID]
FROM SMSPackages_G P inner join v_Package T on P.PkgId = T.PackageID where P.Icon is not null and P.PkgId NOT IN (Select PackageID from v_TaskSequencePackage)
UNION
SELECT Distinct(P.Icon), 'TS' [Type], P.Name [ObjectFullName], PkgID [ContentID]
FROM SMSPackages_G P inner join v_TaskSequencePackage T on P.PkgId = T.PackageID where P.Icon is not null
order by ContentID"

$con = New-Object -TypeName System.Data.SqlClient.SqlConnection
$con.ConnectionString = "Data Source=$Server; Integrated Security=True; Initial Catalog=$Database"
$con.Open()

$cmd = New-Object-TypeName System.Data.SqlClient.SqlCommand -ArgumentList  $Sql, $con
$rd = $cmd.ExecuteReader()

$out = [array]::CreateInstance('Byte', $bufferSize)

$iCount = 0
While ($rd.Read()) {
	$iCount++
	try {
		$start = $rd.GetString(2) #if this is null the try block will error
		$ObjectName = $(try { $rd.GetString(2) } catch { $rd.GegString(3) })
		$FileName = $($rd.GetString(1) + ' - ' + $ObjectName + '.png')
		Write-Output ("$iCount : Exporting Objects from FILESTREM container to [{0}] to [$FileName]" -f $ObjectName)
		$fs = New-Object -TypeName System.IO.FileStream -ArgumentList ($(Join-Path -Path $Path -ChildPath $FileName)), Create, Write;
		$bw = New-Object -TypeName System.IO.BinaryWrite -ArgumentList $fs
		$start = 0
		# Read first byte stream
		$received = $rd.GetBytes(0, $start, $out, 0, $bufferSize - 1)
		While ($received -gt 0) {
			$bw.Write($out, 0, $received)
			$bw.Flush()
			$start += $received
			#Read next byte stream
			$received = $rd.GetBytes(0, $start, $out, 0, $bufferSize - 1)
		}
		$bw.Close()
		$fs.Close()
	} catch {
		Write-Output $_.Exception.Message
	} finally {
		$fs.Dispose()
	}
}

#endregion ########## Main Script ######################################################################################
#region ############# Finalization ########################################################## #BOOKMARK: Script Finalize
$rd.Close()
$cnd.Dispose()
$con.Close()
Write-Output 'Finished'
#endregion ########## Finalization ####################################################################################>