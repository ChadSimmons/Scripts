'******************************************************************************
'Script Name: Get MSI Properties
'Script Description: display vital properties of an MSI
'Script Arguments: [MSI file]
'Script History:
'  2008/05/02: Chad Simmons: added GetSummaryInfo
'  2008/04/09: Chad Simmons: Created
'******************************************************************************

OPTION EXPLICIT
'ON ERROR RESUME Next

'-------------- {BEGIN} Declare and Set Custom Variables ------------------------------
Dim objInstaller, objDB, arrProperties, i, strMSIFile
arrProperties = Split("Manufacturer,ProductName,ProductVersion,ProductVersionMarketing,ProductCode,UpgradeCode,Author,Comments", ",")
Set objInstaller = CreateObject("WindowsInstaller.Installer")
'-------------- {END}   Declare and Set Custom Variables ------------------------------
'-------------- {BEGIN} Declare and Set Global Template Variables & Constants ----------------------
CONST strAppTitle		= "Get MSI Properties"    'the script's title - used in IE display and DB logging
CONST strAppVer			= "1.0" 'the script's version
CONST bLogging			= False 'Log to DBName\ScriptLogs
CONST bEMail			= False 'eMail alerts
CONST bTesting			= False
CONST bDebug			= False
CONST bShowIEonServer	= False 'launch the IE window on server systems
DIM strHTML, strPingMessage, strIPAddress, strTemp, strLog, strObject, strSource, strDate, strTime, strDateTime, strComment, strHost, strUser, strUserDomain, strScriptDir, strScriptEXE, strHTMLTitle, strHTMLHeader, strDBServer, strDBName, strSendAlertAttachment, adCmdText, QT
DIM objConn, objFSO, objShell, objNet, objProcessEnv, objArgs, objRst, objIE, objWMI, objReg, objReport, objIPNetwork, rsObjects
DIM iObjects, iObject, iTemp, iStartSeconds, dStartTime, bCScript, arrAlertIDs, arrFields, iTimeOut
arrFields				= ARRAY("Property","Value") 'Collumn headings (like ComputerName,Status)
Call SetGlobalVariables()
'-------------- {END}   Declare and Set Global Template Variables & Constants ----------------------

'------------------------------------------------------------------------------
'-------------- {BEGIN} Main Script -------------------------------------------
'------------------------------------------------------------------------------

IF objArgs.Count > 0 THEN
	strMSIFile = objArgs(0) 'Set the first argument to the Source
Else
	'strMSIFile = InputBox("Retrieve MSI Details", "Enter the path to an MSI file", "")
	strMSIFile = GetTargets()
End If

If objFSO.FileExists(strMSIFile)Then
Else
	wscript.echo "File not found:" & strMSIFile
	wscript.quit
End If

CALL StartIE() 'Launch IE as a status window
CALL IESize("100%", 285)
CALL IEUpdate (strHTMLTitle & strHTMLHeader & "</TABLE><P>Connecting to MSI database...")

Set objDB = objInstaller.OpenDatabase(strMSIFile, 2)
UpdateLog(ARRAY("FileName",strMSIFile))
For i=0 to Ubound(arrProperties)
   	UpdateLog(ARRAY(arrProperties(i),GetValue(arrProperties(i))))
Next
'Call GetSummaryInfo()
'------------------------------------------------------------------------------
'-------------- {END}   Main Script -------------------------------------------
'------------------------------------------------------------------------------

'-------------- {BEGIN} Clean up and Exit -------------------------------------
CALL IEUpdate(strHTMLHeader & strHTML)
'-------------- {END}   Clean up and Exit -------------------------------------

'******************************************************************************
'********************************** FUNCTIONS *********************************
'******************************************************************************
Sub SetGlobalVariables()
	SET objFSO        = CreateObject("Scripting.FileSystemObject")
	SET objShell      = CreateObject("WScript.Shell")
	SET objArgs       = wscript.Arguments
	strScriptDir      = LEFT(wscript.ScriptFullName,INSTRREV(wscript.ScriptFullName,"\"))
	strScriptEXE      = Right(wscript.FullName, Len(wscript.FullName) - InStrRev(wscript.FullName,"\"))
	strHTMLTitle      = "<CENTER><TABLE BORDER=1 cellpadding=2 cellspacing=0 style='border-collapse: collapse'><TR BGColor=GREEN><TD ColSpan=2><CENTER><FONT FACE=Verdana SIZE=6 Color=WHITE><B>Script Running</TD></TR></TABLE></CENTER><P>"
	strHTMLHeader     = "<CENTER><TABLE BORDER=1 cellpadding=2 cellspacing=0 style='border-collapse: collapse'><TR BGColor=BLACK>"
End Sub
'******************************************************************************
Sub Debug(strMessage)
	If bDebug Then
		If bCScript Then
			wscript.echo strMessage
		Else
			objShell.popup strMessage, 5
		End If
	End If
End Sub
'******************************************************************************
SUB StartIE()  'Setup Internet Explorer for output
   'http://msdn.microsoft.com/library/default.asp?url=/workshop/browser/webbrowser/reference/objects/internetexplorer.asp
	ON ERROR RESUME NEXT
	'IF objShell.RegRead("HKLM\SYSTEM\CurrentControlSet\Control\ProductOptions\ProductType") <> "WinNT" AND bShowIEonServer = False Then Exit Sub 'Running from a server, don't Start IE
	SET objIE = CreateObject("InternetExplorer.Application")
	With objIE : .Navigate "about:blank" : .ToolBar=0 : .StatusBar=0 : .Width=400 : .Height=400 : .Left=0 : .Top=0 : End With
	'objIE.Resizable = 0
	'objIE.Fullscreen = 0
	DO WHILE (objIE.Busy) : wscript.sleep 200 : LOOP
	With objIE : .Document.Title=strAppTitle : .Visible=1 : End With
	wscript.sleep 100
	objIE.document.focus() 'Set the browser to focus which brings it to the top.
	objIE.Document.Body.InnerHTML = "Starting script..."
END SUB  'Updated: 2006/08/17 by Chad Simmons
'******************************************************************************
SUB IEUpdate(strHTML)
   ON ERROR RESUME NEXT
   objIE.Document.Title = FormatPercent((iObject) / iObjects) & " (" & iObject & " of " & iObjects & ") - " & strAppTitle
   objIE.Document.Body.InnerHTML = strHTML
END SUB 'Updated: 2004/10/26 by Chad Simmons
'******************************************************************************
SUB IESize(iWidth,iHeight)
   ON ERROR RESUME NEXT
   'resize the IE window width
   IF INSTR(iWidth,"%") THEN
      objIE.Width  = objIE.document.ParentWindow.screen.width * REPLACE(iWidth,"%","")/100
   ELSE
      objIE.Width  = iWidth
   END IF

   'resize the IE window height
   IF INSTR(iHeight,"%") THEN
      objIE.Height  = objIE.document.ParentWindow.screen.Height * REPLACE(iHeight,"%","")/100
   ELSE
      objIE.Height = iHeight
   END If
END SUB 'Updated: 2004/11/29 by Chad Simmons
'******************************************************************************
SUB UpdateLog(arrLogText)
	ON ERROR RESUME NEXT
	DIM strField, strTempHTML, strTempTXT
	FOR EACH strField IN arrLogText
		strTempTXT = strTempTXT & strField & ","
		strTempHTML = strTempHTML & "<TD>" & strField & "</TD>"
	NEXT
'	strHTML = "<TR>" & strTempHTML & "</TR>" & strHTML 'equiv to "<TR><TD>" & strField1 & "</TD><TD>" & strField2 & "</TD></TR>" & strHTML
	strHTML = strHTML & "<TR>" & strTempHTML & "</TR>" 'equiv to "<TR><TD>" & strField1 & "</TD><TD>" & strField2 & "</TD></TR>" & strHTML
	CALL IEUpdate (strHTMLTitle & strHTMLHeader & strHTML)
	ON ERROR GOTO 0
END SUB
'******************************************************************************
Function GetTargets()
   ON ERROR RESUME NEXT
   'Prompt for source computer or list of computers.  Quit if blank
	Dim objDialog, iResult
	Set objDialog = Createobject("UserAccounts.CommonDialog")
	objDialog.Filter = "Windows Installer Database files|*.msi|All Files|*.*"
	'objDialog.Filter = "Script Scripts|*.vbs;*.js|All Files|*.*"
	objDialog.Filterindex = 1
	objDialog.InitialDir = strScriptDir
	IF objDialog.ShowOpen=0 Then
		wscript.quit
	ELSE
		GetTargets = objDialog.FileName
	END IF
END Function
'******************************************************************************
Function GetValue(strProperty)
	'Retrieve the MSI property value
	On Error Resume Next
	Dim objView, objRec
	Set objView = objDB.OpenView("Select `Value` From Property WHERE `Property` = '" & strProperty & "'")
	objView.Execute
	Set objRec = objView.Fetch
	GetValue = objRec.StringData(1)
End Function
'******************************************************************************
Sub GetSummaryInfo()
	'Retrieve the MSI property value
	On Error Resume Next
	Dim objView, objRec
	Set objView = objDB.OpenView("Select `Property,Value` From SummaryInformation")
	objView.Execute
	Set objRec = objView.Fetch
	Do While Not objRec.EOF
		GetValue = objRec.StringData(1)
		UpdateLog(ARRAY(objRec.Fields("Property"),objRec.Fields("Value")))
		objRec.MoveNext
	Loop
End Sub