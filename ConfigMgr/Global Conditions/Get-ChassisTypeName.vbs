'################################################################################
'#.SYNOPSIS
'#   Get-ChassisTypeName.vbs
'#   Return to standard out the computers chassis type name (desktop, laptop, server, undefined)
'#.DESCRIPTION
'#   Returns the chassis type name based on WMI query of Chassis Type and/or Computer Model
'#.EXAMPLE
'#   cscript.exe /nologo Get-ChassisTypeName.vbs
'#.LINK
'#   Based on https://blogs.technet.microsoft.com/brandonlinton/2013/01/30/configmgr-2012-chassis-type-global-condition/
'#.NOTES
'#   This script is maintained at https://github.com/ChadSimmons/Scripts
'#   Additional information about the function or script.
'#   ========== Keywords ==========
'#   Keywords: Chassis Type Model
'#   ========== Change Log History ==========
'#   - 2018/02/13 by Chad.Simmons@CatapultSystems.com - Created
'#   - 2018/02/13 by Chad@ChadsTech.net - Created
'#   - 2013/01/30 by Brandon Linton - original version
'#   === To Do / Proposed Changes ===
'#   - TODO: None
'#   ========== Additional References and Reading ==========
'#   - ChassisTypes on MSDN: https://msdn.microsoft.com/en-us/library/aa394474(v=vs.85).aspx
'################################################################################

'On Error Resume Next
VerbosePreference = False
arrLaptopModelTypes = Array("Latitude ","Flex","ThinkPad ")
arrDesktopModelTypes = Array("Optiplex "," SFF")
arrServerModelTypes = Array("Server")

Set objWMI = GetObject("winmgmts:{impersonationLevel=impersonate}!\\.\root\cimv2")
Set objResults = objWMI.InstancesOf("Win32_SystemEnclosure")
strChassisType = GetChassisTypeByModel
For each objInstance in objResults
	WriteVerbose "ChassisType is " & objInstance.ChassisTypes(0)
	If objInstance.ChassisTypes(0) = 12 or objInstance.ChassisTypes(0) = 21 Then
		'Ignore docking stations
		strChassisType = "Undefined" 'Docking Stating
	ElseIf strChassisType = "Undefined" Then
		Select Case objInstance.ChassisTypes(0)
			Case "8", "9", "10", "11", "12", "14", "18", "21"
				strChassisType = "Laptop"
			Case "3", "4", "5", "6", "7", "15", "16"
				strChassisType = "Desktop"
			Case "23"
				strChassisType = "Server"
			Case Else
				'none of the defined ChassisTypes IDs on MSDN
				If strChassisType = "" Then
					strChassisType = "Undefined"
				End If
		End Select
		Exit For
	ElseIf strChassisType <> "Undefined" Then
		Exit For 'chassis type defined by model type array
	End If
Next
Wscript.echo strChassisType

Function GetModelName
	Set objWMI = GetObject("winmgmts:{impersonationLevel=impersonate}!\\.\root\cimv2")
	Set objCSs = objWMI.InstancesOf("Win32_ComputerSystem")
	strModelName = ""
	For Each objCS in objCSs
		WriteVerbose "Model Manufacturer is " & objCS.Manufacturer
		If Left(ucase(objCS.Manufacturer),6) = "LENOVO" or Left(ucase(objCS.Manufacturer),3) = "IBM" Then
			Set objCSPs = objWMI.InstancesOf("Win32_ComputerSystemProduct")
			For Each objCSP in objCSPs
				If objCSP.Version <> "" Then
					strModelName = objCSP.Version
					Exit For
				End If
			Next
		Else
			strModelName = objCS.Model
			Exit For
		End If
	Next
	WriteVerbose "Model Name is " & strModelName
	GetModelName = strModelName
End Function

Function GetChassisTypeByModel
	strModelName = GetModelName
	For Each strModelType in arrLaptopModelTypes
		WriteVerbose "Checking Laptop Model Type " & strModelType
		If InStr(UCase(strModelName),UCase(strModelType)) Then
			GetChassisTypeByModel = "Laptop"
			WriteVerbose "ChassisType by Model is Laptop"
			Exit Function
		End If
	Next	

	For Each strModelType in arrDesktopModelTypes
		WriteVerbose "Checking Desktop Model Type " & strModelType
		'If Left(UCase(strModelName),Len(strModelType)) = UCase(strModelType) Then
		If InStr(UCase(strModelName),UCase(strModelType)) Then
			GetChassisTypeByModel = "Desktop"
			WriteVerbose "Chassis Type by Model is Desktop"
			Exit Function
		End If
	Next

	For Each strModelType in arrServerModelTypes
		WriteVerbose "Checking Laptop Model Type " & strModelType
		If InStr(UCase(strModelName),UCase(strModelType)) Then
			GetChassisTypeByModel = "Server"
			WriteVerbose "Chassis Type by Model is Server"
			Exit Function
		End If
	Next	
End Function

Function WriteVerbose (strMessage)
	If VerbosePreference = True Then
		Wscript.echo "VERBOSE: " & strMessage
	End If
End Function