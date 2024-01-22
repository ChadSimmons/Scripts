'#==============================================================================
'#.Synopsis
'#   Backup To WIM
'#.Description
'#   Backup Drive/Folder to WIM keeping multiple backups
'#.Parameter Type
'#   /Type:[WIM|7z|ALL]
'#   Utilities / Archive formats to use
'#.Parameter Path
'#   /Path:"C:\Users\Owner"
'#   Path to the root folder that will be archived
'#.Parameter Destination
'#   /Destination:"B:\Backup"
'#   Path where the arechive file(s) will be created / updated
'#.Parameter Destination2
'#   /Destination2:"A:\Archive"
'#   Path to secondary location where the created archive file(s) will be duplicated
'#.Parameter Name
'#   /Name:"My Backup"
'#   Name of the archive file (WIM and/or 7z)
'#.Parameter WIMConfigFile
'#   /WIMConfigFile:"B:\Backup\My Backup.wim.ini"
'#   File path to WIM exclusion ini
'#.Parameter 7ZConfigFile
'#   /7ZConfigFile:"B:\Backup\My Backup.7z.ini"
'#   File path to WIM exclusion ini
'#.Parameter LogFile
'#   /LogFile:"B:\Backup\My Backup.log"
'#   File path to activity log
'#.Example
'#   cscript.exe /NoLogo Backup-ToWIM.vbs /Path:C:\ /Destination:B:\Backup /Name:"My Backup" /Type:WIM
'#.Example
'#   cscript.exe /NoLogo Backup-ToWIM.vbs /Path:C:\ /Destination:B:\Backup /Destination2:A:\Archive /Name:"My Backup" /Type:ALL /WIMConfigFile:"B:\Backup\My Backup.wim.ini" /WIMConfigFile:"B:\Backup\My Backup.7z.ini"
'#.Notes
'#   === References and Sources ===
'#   === Change Log History ===
'#   2016/10/28 by Chad.Simmons@ChadsTech.net - Created
'#===============================================================================

Option Explicit
'On Error Resume Next
On Error Goto 0

'//---------------------------------------------------------------------------
'//
'// Function: ZTIProcess()
'//
'// Input: None
'//
'// Return: Success - 0
'// Failure - non-zero
'//
'// Purpose: Perform main ZTI processing
'//
'//---------------------------------------------------------------------------

Dim dStartTime : dStartTime = NOW()
Dim dTimer : dTimer = TIMER()
Const strScriptName = "Backup-ToWIM"
Const strScriptVer = "20161028"
Const bTesting = True
Const bDebug = True
Const bDisplayMsgs = True
Const CompressionLevel7z = 0 '4 '9
Dim objFSO, objShell, objNet, strScriptDir, strComputer, strUser, strOSVersion, strOSBuild, strOSArchitecture, strOSType, strWinDir, strSysDir, strSysDrive, strCommonLogsDir 'set by Set_GlobalVariables
Dim spType, spPath, spDestination, spDestination2, spName, spWIMConfigFile, sp7zConfigFile, spLogFile, strLogFile, str7zfile, strPath 'set by Get_Arguments
Dim str7Zexe, strWIMexe 'set by Get_Utilities

Call Set_GlobalVariables()
Call Get_Arguments()
Call Get_Utilities()
Call Make_Archive()
If Len(spDestination2) > 0 Then
	Call Copy_Archive()
End If
Call Log_Message("========================= " & strScriptName & " is complete =========================", bDisplayMsgs)

'##############################################################################
'#################################### FUNCTIONS ###############################
'##############################################################################
Sub Set_GlobalVariables()
	'On Error Resume Next 'do not enable
	Set objFSO = CreateObject("Scripting.FileSystemObject")
	Set objShell = CreateObject("WScript.Shell")
	Set objNet = CreateObject("WScript.Network")
	strScriptDir = Left(wscript.ScriptFullName,InStrRev(wscript.ScriptFullName,"\")-1)
	strComputer = UCase(objNet.ComputerName)
	strUser = UCase(objNet.UserName)
	Const strRegNTcv = "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\"
	strOSVersion = objShell.RegRead(strRegNTcv & "CurrentVersion")
	strOSBuild = objShell.RegRead(strRegNTcv & "CurrentBuildNumber")
	strOSArchitecture = objShell.ExpandEnvironmentStrings("%PROCESSOR_ARCHITECTURE%")
	strOSType = objShell.RegRead("HKLM\SYSTEM\CurrentControlSet\Control\ProductOptions\ProductType")
	strWinDir = objShell.ExpandEnvironmentStrings("%WinDir%")
	strSysDir = objShell.ExpandEnvironmentStrings("%WinDir%") & "\System32"
	strSysDrive = objShell.ExpandEnvironmentStrings("%SystemDrive%")
	strCommonLogsDir = objShell.ExpandEnvironmentStrings("%WinDir%") & "\Logs"
End Sub
'##############################################################################
Function Get_Date(dDate, sFormat)
	On Error Goto 0
	'Set date to now if the passed value is not a date
	If Not IsDate(dDate) Then dDate = Now()
	'Calculate a 4 digit year
	Dim strYear : strYear = Year(dDate) : IF strYear < 80 Then strYear = "20" & strYear 'if the year < 80 then assume 2000's
	IF Len(strYear) < 3  Then strYear = "19" & strYear 'If the year is still 2 digits assume 1900's

	'Apply known / defualt date formatting
	Select Case sFormat
		Case "YYYYMMDD"
			Get_Date = strYear & Right("0" & Month(dDate),2) & Right("0" & Day(dDate),2)
		Case "YYYYMMDD HHMM"
			Get_Date = strYear & Right("0" & Month(dDate),2) & Right("0" & Day(dDate),2) & " " & Right("0" & Hour(dDate),2) & Right("0" & Minute(dDate),2)
		Case "YYYYMMDD_HHMM"
			Get_Date = strYear & Right("0" & Month(dDate),2) & Right("0" & Day(dDate),2) & "_" & Right("0" & Hour(dDate),2) & Right("0" & Minute(dDate),2)
		Case "YYYYMMDD HHMMSS"
			Get_Date = strYear & Right("0" & Month(dDate),2) & Right("0" & Day(dDate),2) & " " & Right("0" & Hour(dDate),2) & Right("0" & Minute(dDate),2) & Right("0" & Second(dDate),2)
		Case "YYYYMMDD_HHMMSS"
			Get_Date = strYear & Right("0" & Month(dDate),2) & Right("0" & Day(dDate),2) & "_" & Right("0" & Hour(dDate),2) & Right("0" & Minute(dDate),2) & Right("0" & Second(dDate),2)
		Case "YYYY/MM/DD HH:MM:SS"
			Get_Date = strYear & "/" & Right("0" & Month(dDate),2)  & "/" & Right("0" & Day(dDate),2) & " " & Right("0" & Hour(dDate),2) & ":" & Right("0" & Minute(dDate),2) & ":" & Right("0" & Second(dDate),2)
		Case Else '"YYYYMMDD_HHMMSS"
			Get_Date = strYear & Right("0" & Month(dDate),2) & Right("0" & Day(dDate),2) & "_" & Right("0" & Hour(dDate),2) & Right("0" & Minute(dDate),2) & Right("0" & Second(dDate),2)
	End Select
End Function
'##############################################################################
Sub Get_Arguments
	'On Error Resume Next
	On Error Goto 0
	'Requires global Dim spType, spPath, spDestination, spDestination2, spName, spWIMConfigFile, sp7zConfigFile, spLogFile, strLogFile

	strLogFile = strCommonLogsDir & "\" & strScriptName & ".log"

	spName = wscript.Arguments.Named.Item("Name")
	If Len(spName) > 0 Then
		'validated spName
		Call Log_Message("spName is '" & spName & "'", bDisplayMsgs)
	Else
'TODO:		Call GetSyntax()
		Call Abort_Script("The backup name was not defined.", True, 160) 'ERROR_BAD_ARGUMENTS
	End If

	spType = UCase(wscript.Arguments.Named.Item("Type"))
	If spType = "WIM" or spType = "7Z" or spType = "ALL" Then
		'validated spType
		Call Log_Message("spType is '" & spType & "'", bDisplayMsgs)
	Else
		'Set the default vaule for the Type parameter
		spType = "WIM"
	End If
	Call Log_Message("spType is '" & spType & "'", bDisplayMsgs)

	spDestination = wscript.Arguments.Named.Item("Destination")
	If objFSO.FolderExists(spDestination) and Len(spDestination) >= 3 Then
		'validated spDestination
		Call Log_Message("spDestination is '" & spDestination & "'", bDisplayMsgs)
	Else
		Call Abort_Script("The destination path '" & spDestination & "' does not exist or is not accessible.", True, 161) 'ERROR_BAD_PATHNAME
	End If

	spLogFile = wscript.Arguments.Named.Item("LogFile")
	If Len(spLogFile) > 0 Then
		strLogFile = spLogFile
		Call Log_Message("LogFile is '" & spLogFile & "'", bDisplayMsgs)
	Else
		strLogFile = spDestination & "\" & spName & ".log"
		Call Log_Message("LogFile was not defined, setting to '" & strLogFile & "'", bDisplayMsgs)
	End If


	Call Log_Message("========================= " & strScriptName & " is starting =========================", bDisplayMsgs)
	Call Log_Message("Script directory:'" & strScriptDir, bDisplayMsgs)
	Call Log_Message("LogFile is '" & strLogFile & "'", bDisplayMsgs)
	Call Log_Message("spName is '" & spName & "'", bDisplayMsgs)
	Call Log_Message("spType is '" & spType & "'", bDisplayMsgs)
	Call Log_Message("spDestination is '" & spDestination & "'", bDisplayMsgs)

	spDestination2 = wscript.Arguments.Named.Item("Destination2")
	If Len(spDestination2) > 0 Then
		If objFSO.FolderExists(spDestination2) and Len(spDestination2) >= 3 Then
			'validated spDestination2
			Call Log_Message("spDestination2 is '" & spDestination2 & "'", bDisplayMsgs)
		Else
			Call Abort_Script("The destination path '" & spDestination2 & "' does not exist or is not accessible.", True, 161) 'ERROR_BAD_PATHNAME
		End If
	End If

	spWIMConfigFile = wscript.Arguments.Named.Item("WIMConfigFile")
	If Len(spWIMConfigFile) > 0 Then
		If objFSO.FileExists(spWIMConfigFile) Then
			'validated spWIMConfigFile
			Call Log_Message("spWIMConfigFile is '" & spWIMConfigFile & "'", bDisplayMsgs)
		Else
			Call Abort_Script("The WIM configration file '" & spWIMConfigFile & "' does not exist or is not accessible.", True, 2) 'ERROR_FILE_NOT_FOUND
		End If
	Else
		spWIMConfigFile = strScriptDir & "\" & strScriptName & ".ini"
		If objFSO.FileExists(spWIMConfigFile) Then
			Call Log_Message("WIMConfigFile was not defined, setting to '" & spWIMConfigFile & "'", bDisplayMsgs)
		Else
			spWIMConfigFile = ""
		End If
	End If

	sp7zConfigFile = wscript.Arguments.Named.Item("7zConfigFile")
	If Len(sp7zConfigFile) > 0 Then
		If objFSO.FileExists(sp7zConfigFile) Then
			'validated sp7zConfigFile
			Call Log_Message("7zConfigFile is '" & sp7zConfigFile & "'", bDisplayMsgs)
		Else
			Call Abort_Script("The 7-zip configration file '" & spWIMConfigFile & "' does not exist or is not accessible.", True, 2) 'ERROR_FILE_NOT_FOUND
		End If
	Else
		sp7zConfigFile = strScriptDir & "\" & strScriptName & ".7Zini"
		If objFSO.FileExists(sp7zConfigFile) Then
			Call Log_Message("7zConfigFile was not defined, setting to '" & sp7zConfigFile & "'", bDisplayMsgs)
		Else
			sp7zConfigFile = ""
		End If
	End If

	spPath = wscript.Arguments.Named.Item("Path")
	If objFSO.FolderExists(spPath) and Len(spPath) >= 3 Then
		'validated spPath
		Call Log_Message("spPath is '" & spPath & "'", bDisplayMsgs)
	Else
		Call Abort_Script("The source path '" & spPath & "' does not exist or is not accessible.", True, 161) 'ERROR_BAD_PATHNAME
	End If
	If Right(spPath,1) = "\" Then
		strPath = Left(spPath,Len(spPath)-1)
	Else
		strPath = spPath
	End If
End Sub
'##############################################################################
Sub Get_Utilities()
	On Error Goto 0
	'#Requires globally defined str7Zexe, strWIMexe
	'#.Snyopsis - determine the backup/archive utilities and command line options
	If spType = "WIM" or spType = "ALL" Then
		If strOSVersion >= 6.0 Then
			'use DISM
			strWIMexe = "DISM.exe"
			Call Log_Message("WIM utility is '" & strWIMexe & "'", bDisplayMsgs)
			If objFSO.FileExists(spDestination & "\" & spName & ".wim") Then
				strWIMexe = strWIMexe & " /Append-Image /CaptureDir:" & chr(34) & strPath & chr(34) & " /ImageFile:" & chr(34) & spDestination & "\" & spName & ".wim" & chr(34) & " /Name:" & chr(34) & spName & " " & Get_Date(Now(),"YYYY/MM/DD HH:MM:SS") & chr(34) & " /ConfigFile:" & chr(34) & spWIMConfigFile & chr(34)
			Else
				strWIMexe = strWIMexe & " /Capture-Image /CaptureDir:" & chr(34) & strPath & chr(34) & " /ImageFile:" & chr(34) & spDestination & "\" & spName & ".wim" & chr(34) & " /Name:" & chr(34) & spName & " " & Get_Date(Now(),"YYYY/MM/DD HH:MM:SS") & chr(34) & " /ConfigFile:" & chr(34) & spWIMConfigFile & chr(34) & " /Compress:max"
			End If
		Else
			'use ImageX
			'Find ImageX command line utility
			If objFSO.FileExists(spPath & "\ImageX.exe") Then
					strWIMexe = spPath & "\ImageX.exe"
			Else
				If objFSO.FileExists(spDestination & "\ImageX.exe") Then
					strWIMexe = spDestination & "\ImageX.exe"
				Else
					If objFSO.FileExists(strScriptDir & "\ImageX.exe") Then
						strWIMexe = strScriptDir & "\ImageX.exe"
					Else
						Call Abort_Script("ImageX.exe does not exist or is not accessible.", True, 2) 'ERROR_FILE_NOT_FOUND
					End If
				End If
			End If
			Call Log_Message("WIM utility is '" & strWIMexe & "'", bDisplayMsgs)

			If objFSO.FileExists(spDestination & "\" & spName & ".wim") Then
				strWIMexe = chr(34) & strWIMexe & chr(34) & " /APPEND " & chr(34) & strPath & chr(34) & " " & chr(34) & spDestination & "\" & spName & ".wim" & chr(34) & " " & chr(34) & spName & " " & Get_Date(Now(),"YYYY/MM/DD HH:MM:SS") & chr(34) & " /CONFIG " & chr(34) & spWIMConfigFile & chr(34)
			Else
				strWIMexe = chr(34) & strWIMexe & chr(34) & " /CAPTURE " & chr(34) & strPath & chr(34) & " " & chr(34) & spDestination & "\" & spName & ".wim" & chr(34) & " " & chr(34) & spName & " " & Get_Date(Now(),"YYYY/MM/DD HH:MM:SS") & chr(34) & " /CONFIG " & chr(34) & spWIMConfigFile & chr(34) & " /COMPRESS maximum"
			End If
		End If
		Call Log_Message("WIM command is '" & strWIMexe & "'", bDisplayMsgs)
	End If

	If spType = "7Z" or spType = "ALL" Then
		'Find 7-zip command line utility
		If objFSO.FileExists(spPath & "\7za.exe") Then
				str7Zexe = spPath & "\7za.exe"
		Else
			If objFSO.FileExists(spDestination & "\7za.exe") Then
				str7Zexe = spDestination & "\7za.exe"
			Else
				If objFSO.FileExists(strScriptDir & "\7za.exe") Then
					str7Zexe = strScriptDir & "\7za.exe"
				Else
					Call Abort_Script("7za.exe does not exist or is not accessible.", True, 2) 'ERROR_FILE_NOT_FOUND
				End If
			End If
		End If
		Call Log_Message("7-zip utility is '" & str7Zexe & "'", bDisplayMsgs)

		Dim str7zExclude
		If objFSO.FileExists(sp7zConfigFile) Then
			'#.Link for a good example see
			'#   https://sourceforge.net/p/sevenzip/discussion/45797/thread/e456a547/
			'#   https://www.experts-exchange.com/questions/27551900/7zip-exclude-a-list-of-directories-and-their-content.html
			str7zExclude = "-x@" & chr(34) & sp7zConfigFile & chr(34) & " -xr@" & chr(34) & sp7zConfigFile & chr(34) & " "
		Else
			str7zExclude = "-xr!~*.* -xr!*.tmp -xr!*.lock -xr!thumbs.db -xr!pagefile.sys -xr!hiberfil.sys -xr!$ntfs.log -xr!" & chr(34) & "Temporary Internet Files" & chr(34) & " -xr!Temp -x!" & chr(34) & "System Volume Information" & chr(34) & " -x!RECYCLE.BIN -x!$RECYCLE.BIN -x!RECYCLER -x!MININT -x!Windows.old -x!Windows\Logs -x!Windows\CSC -x!Windows\Panther -x!Windows\SoftwareDistribution -x!_SMSTaskSequence -x!inetpub\logs "
		End If
		str7zfile = spName & "." & Get_Date(Now(),"YYYYMMDD_HHMM") & ".7z"
		str7Zexe = chr(34) & str7Zexe & chr(34) & " a -mx" & CompressionLevel7z & " -t7z -r " & str7zExclude & chr(34) & spDestination & "\" & str7zfile & chr(34) & " " & chr(34) & strPath & "\*.*" & chr(34)
		Call Log_Message("7-zip command is '" & str7Zexe & "'", bDisplayMsgs)
	End If

End Sub
'##############################################################################
Sub Copy_Archive
	On Error Resume Next
	Const OverwriteExisting = True
	Call Log_Message("Copying WIM archive '" & spDestination & "\" & spName & ".wim" & "' to '" & spDestination2 & "'", bDisplayMsgs)
	objFSO.CopyFile spDestination & "\" & spName & ".wim", spDestination2 & "\" & spName & ".wim", OverwriteExisting
	If Err.Number = 0 Then
		Call Log_Message("Copied archive to '" & spDestination2 & "'", bDisplayMsgs)
	Else
		iReturnCode = Err.Number
		Call Log_Message("Failed to copy backup with error code '" & iRC & "'", bDisplayMsgs)
	End If

	Call Log_Message("Copying 7-zip archive '" & spDestination & "\" & str7zfile & "' to '" & spDestination2 & "'", bDisplayMsgs)
	objFSO.CopyFile spDestination & "\" & str7zfile, spDestination2 & "\" & str7zfile, OverwriteExisting
	If Err.Number = 0 Then
		Call Log_Message("Copied archive to '" & spDestination2 & "'", bDisplayMsgs)
	Else
		iReturnCode = Err.Number
		Call Log_Message("Failed to copy backup with error code '" & iRC & "'", bDisplayMsgs)
	End If

	If iReturnCode <> 0 Then Call Abort_Script("One or more archives failed to copy", bDisplayMsgs, iReturnCode)
End Sub
'##############################################################################
Sub Make_Archive()
	On Error Resume Next
	DIM iRC, iReturnCode
	Const iWS_Hide = 0
	Const iWS_Show = 1
	iReturnCode = 0

	'http://www.codeproject.com/Tips/507798/Differences-between-Run-and-Exec-VBScript
	'http://devguru.com/content/technologies/wsh/17419.html
	objShell.CurrentDirectory = strScriptDir
    iRC = objShell.Run(strWIMexe, iWS_Show, True)
	If iRC = 0 Then
		'verify the file changed based on timestamp and is > a few bytes
		If objFSO.FileExists(spDestination & "\" & spName & ".wim") Then
'#TODO: verify file is valid ... dism /Get-WimInfo /WimFile:"d:\Temp\Drive F.wim"
'#TODO: log file size and modified time
'#			iReturnCode = 13 'ERROR_INVALID_DATA
'#			Call Log_Message("WIM backup cannout be found or is invalid.'" & iRC & "'", bDisplayMsgs)
		Else
			iReturnCode = 2 'ERROR_FILE_NOT_FOUND
			Call Log_Message("WIM backup cannout be found or is invalid.'" & iRC & "'", bDisplayMsgs)
		End If
	Else
		iReturnCode = 2 'ERROR_FILE_NOT_FOUND
		Call Log_Message("WIM backup failed with return code is '" & iRC & "'", bDisplayMsgs)
	End If

    iRC = objShell.Run(str7Zexe, iWS_Show, True)
	If iRC = 0 Then
		'verify the file exists and is > a few bytes
		If objFSO.FileExists(spDestination & "\" & str7zfile) Then
'#TODO: verify file is valid
'#TODO: log file size and modified time
'#			iReturnCode = 13 'ERROR_INVALID_DATA
'#			Call Log_Message("7-zip backup cannout be found or is invalid.'" & iRC & "'", bDisplayMsgs)
		Else
			iReturnCode = 2 'ERROR_FILE_NOT_FOUND
			Call Log_Message("7-zip backup cannout be found or is invalid.'" & iRC & "'", bDisplayMsgs)
		End If
	Else
		iReturnCode = iRC
		Call Log_Message("7-zip backup failed with return code is '" & iRC & "'", bDisplayMsgs)
	End If

	If iReturnCode <> 0 Then Call Abort_Script("One or more archives failed", bDisplayMsgs, iReturnCode)
End Sub
'##############################################################################
Sub Log_Message (strMessage, bDisplay)
	'#Requires globally defined strLogFile
	On Error Resume Next
	'On Error Goto 0
	Dim objLog, strDate
	Const ForAppending = 8
	Const ForWriting = 2
	Const CreateOverwrite = True

	strDate = Get_Date(Now(),"YYYY/MM/DD HH:MM:SS")
	If bDisplay = True Then
		wscript.echo strDate & vbTab & strMessage
	End If

	Set objLog = objFSO.OpenTextFile(strLogFile, ForAppending, CreateOverwrite)
	If Err.Number <> 0 Then
		WScript.Echo "Error " & Err.Number & " (" & Err.Description & ") writing to log file " & strLogFile
		WScript.Quit Err.Number '29 'ERROR_WRITE_FAULT
	End If
	objLog.writeline strDate & "," & strMessage
	objLog.close
End Sub
'##############################################################################
Sub Abort_Script (strMessage, bDisplay, iReturnCode)
	Call Log_Message ("ABORT: " & strMessage, bDisplay)
	Call Log_Message ("ABORT: return/exit/error code " & iReturnCode, bDisplay)
	Call Log_Message("========================= " & strScriptName & " is complete =========================", bDisplayMsgs)
	wscript.quit iReturnCode
End Sub'##############################################################################
