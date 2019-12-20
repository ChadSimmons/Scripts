'******************************************************************************
' Name:			Set-ImageInfo-Deploy.vbs
' Description: 		Sets System Image Information during a Deploy event
' Author:		Chad.Simmons@CatapultSystems.com
' Date:			20140612
'******************************************************************************
Option Explicit
On Error Resume Next

'************************* DO NOT MODIFY BELOW THIS LINE *************************
Dim objShell : Set objShell = CreateObject("WScript.Shell")
Const RegPath="HKLM\Software\Microsoft\Windows\CurrentVersion\Uninstall\Image Information\"

' Set Image Information
objShell.RegWrite RegPath & "InstallDate", YYYYMMDD(Now()), "REG_SZ"

Function YYYYMMDD(dDate)
	On Error Resume NEXT
	If Not IsDate(dDate) Then dDate = Now()	'Set dDate to NOW() if it is not a date
	'Parse out each component from the full date time stamp
	Dim strYear   : strYear	   = Year(dDate)
		IF strYear        < 80 Then strYear   = "20" & strYear   'The year < 80 then assume 2000's
		IF Len(strYear)   < 3  Then strYear   = "19" & strYear 	'The year is still 2 digits so assume 1900's
	YYYYMMDD = strYear & Right("0" & Month(dDate),2) & Right("0" & Day(dDate),2)
	On Error Goto 0
End Function