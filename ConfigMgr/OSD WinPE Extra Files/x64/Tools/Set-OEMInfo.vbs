'******************************************************************************
' Name:			Set-OEMInfo.vbs
' Description: 		Sets OEM Info (Manufacturer, Model, etc.)
' Author:		Chad.Simmons@CatapultSystems.com
' Date:			20140612
'******************************************************************************
Option Explicit
On Error Resume Next

Const MFGCustomText = " (provisioned by Catapult Systems)"
Const strRegPath = "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\OEMInformation\"
Dim objWMIService, colWMI, objWMI, Manufacturer, Model, objShell, colCSP

Set objWMIService = GetObject("winmgmts:\\" & "." & "\root\cimv2")
Set objShell = wscript.CreateObject("wscript.shell")

Set colWMI = objWMIService.ExecQuery("Select Manufacturer,Model from Win32_ComputerSystem")
For Each objWMI In colWMI
	Model = objWMI.Model
	Manufacturer = objWMI.Manufacturer
Next

'sanatize the manufacturer
If Left(UCase(Manufacturer), 3) = "IBM" Or Left(UCase(Manufacturer), 6) = "LENOVO" Then
	Manufacturer = "Lenovo"
	Set colCSP = objWMIService.ExecQuery("Select Version from Win32_ComputerSystemProduct")
	For Each objWMI In colCSP
		Model = objWMI.Version
	Next
ElseIf Left(UCase(Manufacturer), 4) = "DELL" Then
	Manufacturer = "Dell"
End If

'reg write MFG,Model
objShell.RegWrite strRegPath & "Manufacturer", Manufacturer & MFGCustomText, "REG_SZ"
objShell.RegWrite strRegPath & "Model", Model, "REG_SZ"