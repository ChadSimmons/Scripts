'region    Comment Based Help ##################################################
Option Explicit
On Error Resume Next
Dim H
H = H & vbCRLF & "###############################################################################"
H = H & vbCRLF & ".SYNOPSIS"
H = H & vbCRLF & "   ScriptFileName.vbs"
H = H & vbCRLF & "   A brief description of the function or script. This keyword can be used only once in each topic."
H = H & vbCRLF & ".DESCRIPTION"
H = H & vbCRLF & "   A detailed description of the function or script. This keyword can be used only once in each topic."
H = H & vbCRLF & ".PARAMETER <name>"
H = H & vbCRLF & "   Specifies <xyz>"
H = H & vbCRLF & "   /NAME:<xyz>"
H = H & vbCRLF & ".EXAMPLE"
H = H & vbCRLF & "   ScriptFileName.vbs /Parameter1:XYZ"
H = H & vbCRLF & "   A sample command that uses the function or script, optionally followed by sample output and a description. Repeat this keyword for each example."
H = H & vbCRLF & ".LINK"
H = H & vbCRLF & "   Link Title: http://contoso.com/ScriptFileName.txt"
H = H & vbCRLF & "   The name of a related topic. The value appears on the line below the .LINE keyword and must be preceded by a comment symbol (#) or included in the comment block."
H = H & vbCRLF & "   Repeat the .LINK keyword for each related topic."
H = H & vbCRLF & "   This content appears in the Related Links section of the help topic."
H = H & vbCRLF & "   The Link keyword content can also include a Uniform Resource Identifier (URI) to an online version of the same help topic. The online version  opens when you use the Online parameter of Get-Help. The URI must begin with "http" or "https"."
H = H & vbCRLF & ".NOTES"
H = H & vbCRLF & "   This script is maintained at https://github.com/ChadSimmons/Scripts"
H = H & vbCRLF & "   Additional information about the function or script."
H = H & vbCRLF & "   ========== Keywords =========="
H = H & vbCRLF & "   Keywords: ???"
H = H & vbCRLF & "   ========== Change Log History =========="
H = H & vbCRLF & "   - yyyy/mm/dd by Chad Simmons - Modified $ChangeDescription$"
H = H & vbCRLF & "   - yyyy/mm/dd by Chad.Simmons@CatapultSystems.com - Created"
H = H & vbCRLF & "   - yyyy/mm/dd by Chad@ChadsTech.net - Created"
H = H & vbCRLF & "   === To Do / Proposed Changes ==="
H = H & vbCRLF & "   - TODO: None"
H = H & vbCRLF & "   ========== Additional References and Reading =========="
H = H & vbCRLF & "   - <link title>: https://domain.url"
H = H & vbCRLF & "###############################################################################"
'Display Help if requested
Dim strArg, colArgs : Set colArgs = WScript.Arguments.Named
For Each strArg in colArgs
	strArg = UCase(strArg)
	If (strArg = "HELP" or strArg = "H" or strArg = "?") Then
		wscript.echo wscript.scriptname & H
		wscript.quit 0
	End If
Next
'endregion Comment Based Help ##################################################


'region    Declare and Set Custom Variables ####################################

'endregion Declare and Set Custom Variables ####################################
'region    Declare and Set Global Template Variables & Constants ###############
Const strScriptTitle	= ""    'the script's title - used in IE display and DB logging
Const strScriptVersion	= "1.0" 'the script's version
Const bLogging			= True 'Log to DBName\ScriptLogs
Const bEMail			= True 'eMail alerts
Const bTesting			= False
Const bDebug			= False
Const bDebugVerbose		= False
Const bShowIEonServer	= False 'launch the IE window on server systems
Dim strHTML, strPingMessage, strIPAddress, strTemp, strLog, strObject, strReport, strSource, strDate, strTime, strDateTime, strComment, strComputerName, strUser, strUserDomain, strScriptDir, strScriptEXE, strHTMLTitle, strHTMLHeader, strDBServer, strDBName, strSendAlertAttachment, adCmdText, QT
Dim objConn, objFSO, objShell, objNet, objProcessEnv, objArgs, objRst, objIE, objWMI, objReg, objReport, rsObjects
Dim iObjects, iObject, iTemp, iStartSeconds, dStartTime, bCScript, arrAlertIDs, arrFields
strDBServer				= "mySQLdatabase.lab.local"
strDBName				= "CMDB"
arrAlertIDs				= Array("UserID1","UserID2") 'IDs that will be emailed in the SendAlert Function
arrFields				= Array("Field1","Field2") 'Collumn headings (like ComputerName,Status)
strSendAlertAttachment	= ""
Call SetGlobalVariables()
'endregion Declare and Set Global Template Variables & Constants ###############

'###############################################################################
'###############################################################################
'region    Main Script #########################################################

IF objArgs.Count > 0 Then strSource = objArgs(0) 'Set the first argument to the Source
Call GetTargets(strSource) 'Get the list of targets

IF objArgs.Count > 1 Then strReport = objArgs(1) 'Set the second  argument to the Report
Call StartReport(strReport) 'Create an output file for the targets

Call StartIE() 'Launch IE as a status window
'CALL IESize(750, "50%")
Call IEUpdate (strHTMLTitle & strHTMLHeader & "</TABLE><P>Script starting...")

'----- Loop through the recordset of objects
'rsObjects.Filter = "Col1 LIKE '%-1%'"	'filter the recordset
'rsObjects.Filter = ""	'unfilter the recordset
'rsObjects.Sort = "Col1 ASC" 'sort the recordset
DO UNTIL rsObjects.EOF
	iObject = iObject + 1
	strObject = Trim(CStr(rsObjects(0)))
	If Ping(strObject) = True Then
	   'Set objWMI = GetObject("winmgmts:{impersonationLevel=impersonate}!\\" & strObject & "\root\cimv2")
	   'Set objReg = GetObject("winmgmts:{impersonationLevel=impersonate}!\\" & strObject & "\root\default:StdRegProv")
	   'iTemp = CALL ProcessMonitor ("notepad.exe",0)
		UpdateLog(Array(strObject,strPingMessage))
	Else
		UpdateLog(Array(strObject,strPingMessage))
	END IF
   'CALL IEUpdate (strHTMLTitle & strHTMLHeader & strHTML)
   rsObjects.MoveNext
LOOP

'###############################################################################
'###############################################################################
'endregion Main Script #########################################################


'region    Clean up and Exit ###################################################
strHTMLTitle = "<CENTER><TABLE BORDER=1 cellpadding=2 cellspacing=0 style='border-collapse: collapse'><TR BGColor=RED><TD ColSpan=2><CENTER><FONT FACE=Verdana SIZE=6 Color=WHITE><B>Script Complete</TD></TR><TR><TD>Start Time:</TD><TD>" & dStartTime & "</TD></TR><TR><TD>End Time:</TD><TD>" & Now & "</TD></TR><TR><TD>Elapsed Seconds:</TD><TD>" & (Timer-iStartSeconds) & "</TD></TR><TR><TD>Objects:</TD><TD>" & iObjects & "</TD></TR><TR><TD>Seconds Per Object:</TD><TD>" & (Timer-iStartSeconds) / iObjects & "</TD></TR></TABLE></CENTER><P>"
Call UpdateLog("Start Time," & dStartTime & ",End Time," & Now & ",Elapsed Seconds," & (Timer-iStartSeconds))

IF objShell.RegRead("HKLM\SYSTEM\CurrentControlSet\Control\ProductOptions\ProductType") <> "WinNT" Then 'close IE if ran from a standard server
   wscript.sleep 2000
   If IsObject(objIE) Then objIE.quit
Else
	'objReport.CLOSE
	'objShell.RUN "notepad.exe " & strReport      'Open the report in Notepad
END IF

wscript.quit
'endregion Clean up and Exit ###################################################

'###############################################################################
'region    FUNCTIONS ###########################################################
'###############################################################################
Sub SetGlobalVariables()
	Set rsObjects     = CreateObject("ADODB.RecordSet") 'Create an ADO disconnected RecordSet
	Set objConn       = CreateObject("ADODB.Connection")'Create an ADO RecordSet to a SQL DB
	Set objFSO        = CreateObject("Scripting.FileSystemObject")
	Set objShell      = CreateObject("WScript.Shell")
	Set objProcessEnv = objShell.Environment("Process") 'Connect to the Process Environment variables [alternate syntax: objShell.Environment("PROCESS")("VARIABLE")]
	Set objArgs       = wscript.Arguments
	QT                = Chr(34)
	dStartTime        = Now()
	iStartSeconds     = Timer()
	strComputerName   = UCase(objShell.ExpandEnvironmentStrings("%ComputerName%"))
	strUser           = UCase(objShell.ExpandEnvironmentStrings("%UserName%"))
	strUserDomain     = UCase(objShell.ExpandEnvironmentStrings("%UserDomain%"))
	strScriptDir      = objFSO.GetParentFolderName(wscript.ScriptFullName)
	strScriptEXE      = Right(wscript.FullName, Len(wscript.FullName) - InStrRev(wscript.FullName,"\")) 'this returns cscript.exe or wscript.exe
	strScript 		  = Right(wscript.ScriptFullName, Len(wscript.ScriptFullName) - InStrRev(wscript.ScriptFullName, "\"))
	strHTMLTitle      = "<CENTER><TABLE BORDER=1 cellpadding=2 cellspacing=0 style='border-collapse: collapse'><TR BGColor=GREEN><TD ColSpan=2><CENTER><FONT FACE=Verdana SIZE=6 Color=WHITE><B>Script Running</TD></TR><TR><TD>Start Time:</TD><TD>" & dStartTime & "</TD></TR></TABLE></CENTER><P>"
	strHTMLHeader     = "<CENTER><TABLE BORDER=1 cellpadding=2 cellspacing=0 style='border-collapse: collapse'><TR BGColor=BLACK>"
	If InStr(UCase(WScript.FullName),"WSCRIPT.EXE") Then
	   bCScript = 0
	Else
	   bCScript = 1
	End If
End Sub   'Updated: 2007/09/25 by Chad Simmons
'###############################################################################
SUB MSGLog(strLog) 'Log DateTimeStamp,strScriptTitle,strLog to the DCMDB\ScriptLogs table
   On Error Resume Next
   Call Debug(strLog)
   IF bLogging Then
      Dim objRstLog : Set objRstLog = objConn.Execute ("INSERT INTO ScriptLogs VALUES (GetDate(),'" & strScriptTitle &  "','" & strLog & "')", , adCmdText)
      strLog = ""
      wscript.sleep(500)
   END IF
   ERR.CLEAR
   On Error Goto 0
END SUB   'Updated: 2005/03/31 by Chad Simmons
'###############################################################################
Sub Debug(strMessage)
	If bDebug Then
		If bCScript Then
			wscript.echo strMessage
		Else
			objShell.popup strMessage, 5
		End If
	End If
End Sub
'###############################################################################
Sub DebugVerbose(strMessage)
	If bDebugVerbose Then
		If bCScript Then
			wscript.echo strMessage
		Else
			objShell.popup strMessage, 5
		End If
	End If
End Sub
'###############################################################################
Sub SendAlert(strLog) 'Send an email to each ID in AlertIDs
   On Error Resume Next
   If bEMail = True Then
		Dim objEmail : Set objEmail = CreateObject("CDO.Message")
		Const CDOcfg = "http://schemas.microsoft.com/cdo/configuration/"
		With objEmail.Configuration.Fields
			.Item(CDOcfg & "sendusing") = 2
			.Item(CDOcfg & "smtpserver") = "smtp.lab.local"
			.Item(CDOcfg & "smtpserverport") = 465 '25
			.Item(CDOcfg & "smtpusessl") = True
			.Item(CDOcfg & "smtpauthenticate") = 1 'basic (clear text) authentication
			.Item(CDOcfg & "sendusername") = "myEmail@lab.local"
			.Item(CDOcfg & "sendpassword") = "myPassword"
			.Update
		End With
		objEmail.From = "Script <myEmail@lab.local>"
		objEmail.To = "myEmail@lab.local;" & strEmailAddresses
		objEmail.Subject = "Script_" & strScriptTitle & " - " & Now()
		objEmail.Textbody = strLog
		If Right(strSendAlertAttachment, 4) = ".txt" Then
			Dim objAttachmentFile : Set objAttachmentFile = objFSO.OpenTextFile(strSendAlertAttachment)
			strLog = strLog & VBLF & VBLF & objAttachmentFile.ReadAll 'read the text file into a variable (buffer)
			objAttachmentFile.CLOSE
		ElseIf strSendAlertAttachment <> "" Then
			objEmail.AddAttachment strSendAlertAttachment
		End If
		objEmail.Send
	End If
	Call MSGLog(strLog)
End Sub 'Updated: 2010/03/16 by Chad Simmons
'###############################################################################
SUB DBUpdateable() 'Test to see if the Database (not table) can be updated
   On Error Resume NEXT
   Dim dUpdate : dUpdate = Now()
   Dim objRstTest : Set objRstTest = objConn.Execute("DELETE Updateable",,adCmdText)
   Set objRstTest = objConn.Execute("INSERT INTO Updateable VALUES('" & dUpDate &"')",,adCmdText)
   Set objRstTest = objConn.Execute("SELECT TOP 1 * FROM Updateable",,adCmdText)
   IF objRstTest(0) <> dUpDate Then
		Call SendAlert("Error - Database not updateable.  Script Aborted")
		Call objShell.popup(strLog, 5)
		wscript.quit
   END If
   On Error Goto 0
END SUB   'Updated: 2005/03/31 by Chad Simmons
'###############################################################################
SUB GetNewDateTime(dNow) 'Prepare a date value in the correct format for file and folder creation
   On Error Resume NEXT
   IF Not IsDate(dNow) Then dNow = Now()	'Set dNow to NOW() if it is not a date
   'Parse out each component from the full date time stamp
   Dim strYear   : strYear	   = Year(dNow)   : IF strYear        < 80 Then strYear   = "20" & strYear   'The year < 80 then assume 2000's
                                               IF Len(strYear)   < 3  Then strYear   = "19" & strYear 	'The year is still 2 digits so assume 1900's
   strDate     = strYear & "/" & Right("0" & Month(dNow),2)  & "/" & Right("0" & Day(dNow),2)
   strTime     = Right("0" & Hour(dNow),2) & ":" & Right("0" & Minute(dNow),2) & ":" & Right("0" & Second(dNow),2)
   strDateTime = Replace(strDate,"/","") & "_" & Replace(strTime,":","")
   On Error Goto 0
END SUB   'Updated: 2006/07/26 by Chad Simmons
'###############################################################################
SUB StartIE()  'Setup Internet Explorer for output
   'http://msdn.microsoft.com/library/default.asp?url=/workshop/browser/webbrowser/reference/objects/internetexplorer.asp
	On Error Resume NEXT
	IF objShell.RegRead("HKLM\SYSTEM\CurrentControlSet\Control\ProductOptions\ProductType") <> "WinNT" And bShowIEonServer = False Then Exit Sub 'Running from a server, don't Start IE
	Set objIE = CreateObject("InternetExplorer.Application")
	With objIE : .Navigate "about:blank" : .ToolBar=0 : .StatusBar=0 : .Width=400 : .Height=400 : .Left=0 : .Top=0 : End With
	'objIE.Resizable = 0
	'objIE.Fullscreen = 0
	DO WHILE (objIE.Busy) : wscript.sleep 200 : LOOP
	With objIE : .Document.Title=strScriptTitle : .Visible=1 : End With
	wscript.sleep 100
	objIE.document.focus() 'Set the browser to focus which brings it to the top.
	objIE.Document.Body.InnerHTML = "Starting script..."
END SUB  'Updated: 2006/08/17 by Chad Simmons
'###############################################################################
SUB IEUpdate(strHTML)
   On Error Resume NEXT
   objIE.Document.Title = FormatPercent((iObject) / iObjects) & " (" & iObject & " of " & iObjects & ") - " & strScriptTitle
   objIE.Document.Body.InnerHTML = strHTML
END SUB 'Updated: 2004/10/26 by Chad Simmons
'###############################################################################
SUB IESize(iWidth,iHeight)
   On Error Resume NEXT
   'resize the IE window width
   IF InStr(iWidth,"%") Then
      objIE.Width  = objIE.document.ParentWindow.screen.width * Replace(iWidth,"%","")/100
   Else
      objIE.Width  = iWidth
   END IF

   'resize the IE window height
   IF InStr(iHeight,"%") Then
      objIE.Height  = objIE.document.ParentWindow.screen.Height * Replace(iHeight,"%","")/100
   Else
      objIE.Height = iHeight
   END If
END SUB 'Updated: 2004/11/29 by Chad Simmons
'###############################################################################
Function Ping(strComputer)
	On Error Resume Next
	Dim objPing, objRetStatus
	Set objPing = GetObject("winmgmts:{impersonationLevel=impersonate}").ExecQuery ("select * from Win32_PingStatus where address = '" & strComputer & "' AND ResolveAddressNames = TRUE")
	For each objRetStatus In objPing
		If IsNull(objRetStatus.StatusCode) Or objRetStatus.StatusCode<>0 Then
			Ping = False
		Else
			Ping = True
		End if
	Next
End Function 'Updated: 2009/05/01 by Sudheer Bangera
'###############################################################################
FUNCTION ProcessMonitor(strProcessToMonitor,iMAXProcesses)
	On Error Resume NEXT
   'Monitor the number of instances of a defined process name and wait until it drops below the defined maximum
   Dim i
   Dim objWMIProcesses : Set objWMIProcesses = GetObject("winmgmts:\\" & strComputerName & "\root\cimv2")
   Dim colProcessList  : Set colProcessList = objWMIProcesses.ExecQuery ("SELECT ProcessID FROM Win32_Process WHERE Name = '" & strProcessToMonitor & "'")
   DO WHILE colProcessList.Count >= iMAXProcesses
      wscript.sleep 1000
      i = i + 1
      IEUpdate strHTMLTitle & "Waiting " & i & " seconds for " & colProcessList.Count & " process(es) to complete.<P>" & strHTMLHeader & strHTML
      Set colProcessList = objWMIProcesses.ExecQuery ("SELECT ProcessID FROM Win32_Process WHERE Name = '" & strProcessToMonitor & "'")
   LOOP
   ProcessMonitor = i
   On Error Goto 0
END FUNCTION 'Updated: 2004/11/12 by Chad Simmons
'###############################################################################
SUB StartReport(strTarget) 'Create the report (delete the existing one)
	On Error Resume NEXT
	IF strTarget <> "" Then strSource = strTarget

   IF strSource = "" Then strSource = strScriptTitle
   IF strSource = "" Then strSource = "Undefined"

   IF strSource = "." Then
      strReport = "C:\Temp\" & strComputerName & ".csv"
   ElseIf objFSO.FileExists(strSource) Then
      strReport = Mid(strSource,1,Len(strSource)-4) & ".csv"
	ElseIf InStr(UCase(strSource), "SELECT ") Then
		strReport = "C:\Temp\SQLReport.csv"
   Else
		strReport = "C:\Temp\" & strSource & ".csv"
   END IF

   IF objFSO.FileExists(strReport) Then objShell.Popup "The report file '" & strReport & "' already exists.", 5, "Overwrite Output File?", 48

   Set objReport = objFSO.OpenTextFile(strReport, 2, True) 'open the report to write/overwrite
   IF ERR.NUMBER <> 0 Then
   	MsgBox "The report file (" & strReport & ") could not be accessed."
   	wscript.quit(1)
   END IF

   'Build and write the Report headers
	Dim strTempTXT
	FOR EACH strTemp In arrFields
      'Prevent duplicate HTML headers when using multiple report files
		IF Right(strHTMLHeader,5) <> "</TR>" Then strHTMLHeader = strHTMLHeader & "<TD><FONT FACE=Verdana Color=WHITE><B>" & strTemp & "</TD>"
		strTempTXT = strTempTXT & strTemp & ","
	NEXT
	IF InStr(Len(strTempTXT)-1,strTempTXT,",") Then strTempTXT = Left(strTempTXT,Len(strTempTXT)-1) 'kill the trailing comma
	objReport.writeline strTempTXT
	strHTMLHeader = strHTMLHeader & "</TR>"

   On Error Goto 0
END SUB 'Updated: 2005/11/08 by Chad Simmons
'###############################################################################
SUB GetTargets(strTarget)
   On Error Resume NEXT
   'Prompt for source computer or list of computers.  Quit if blank
   IF strTarget = "" Then
      strTarget = Trim(InputBox ("Enter '.' for the current computer" & VBLF & "Enter a computer name for one remote computer" & VBLF & "Or enter the file that contains the list of Computer Names.", "Computer Names","C:\Temp\ComputerList.txt"))
      IF strTarget = "" Then wscript.quit
   END IF
	strSource = strTarget	'set the Global var = to the local var so it can be used in other functions

   'Convert "." to this computer's hostname
   IF strSource = "." Then strSource = objNet.ComputerName

   'Determine if SOURCE is a file.  If so, read the contents of the file into a recordset.
   'IF Source contains the SQL keyword "SELECT" connect to the DB and create a recordset
   'ELSE create a recordset of 1 element, strSOURCE
   IF objFSO.FileExists(strSource) Then
      Dim objReadFile : Set objReadFile = objFSO.OpenTextFile(strSource)
      rsObjects.Fields.Append "Col1", 200, 255 'Create a RecordSet of 1 VarChar Column of 255(variant) length
      rsObjects.Open 'Open the RecordSet
      DO UNTIL objReadFile.AtEndOfStream
         rsObjects.AddNew
         rsObjects.Fields(0) = objReadFile.ReadLine
         iObjects = iObjects + 1
      LOOP
      objReadFile.CLOSE
   ElseIf InStr(UCase(strSource),"SELECT ") Then
      IF strDBServer = "" Then strDBServer = Trim(InputBox ("Enter the DB Server name", "DB Server Name",strDBServer))
      IF strDBName = "" Then strDBName = Trim(InputBox ("Enter the DB name", "DB Name",strDBName))
      objConn.Open "Provider=SQLOLEDB.1;Integrated Security=SSPI;Initial Catalog=" & strDBName & ";Data Source=" & strDBServer
      DBUpdateable()
      Set rsObjects = objConn.Execute(strSource, , adCmdText)
      DO UNTIL rsObjects.EOF
         iObjects = iObjects + 1
         rsObjects.MoveNext
      LOOP
   Else
      rsObjects.Fields.Append "Col1", 200, 255 'Create a RecordSet of 1 VarChar Column of 255(variant) length
      rsObjects.Open 'Open the RecordSet
      rsObjects.AddNew
      rsObjects.Fields(0) = strSource
      iObjects = 1
   END IF

   rsObjects.MoveFirst
   IF iObjects < 1 Then iObjects = 1 'we will always be processing at least 1 record
   On Error Goto 0
END SUB 'Updated: 2004/11/17 by Chad Simmons
'###############################################################################
SUB UpdateLog(arrLogText)
	On Error Resume NEXT
	Dim strField, strTempHTML, strTempTXT
	FOR EACH strField In arrLogText
		strTempTXT = strTempTXT & strField & ","
		strTempHTML = strTempHTML & "<TD>" & strField & "</TD>"
	NEXT
	IF InStr(Len(strTempTXT)-1,strTempTXT,",") Then strTempTXT = Left(strTempTXT,Len(strTempTXT)-1) 'kill the trailing comma
	objReport.writeline strTempTXT
	strHTML = "<TR>" & strTempHTML & "</TR>" & strHTML 'equiv to "<TR><TD>" & strField1 & "</TD><TD>" & strField2 & "</TD></TR>" & strHTML
	Call IEUpdate (strHTMLTitle & strHTMLHeader & strHTML)
	On Error Goto 0
END SUB 'Updated: 2004/10/26 by Chad Simmons
'###############################################################################
'endregion FUNCTIONS ###########################################################
'###############################################################################
