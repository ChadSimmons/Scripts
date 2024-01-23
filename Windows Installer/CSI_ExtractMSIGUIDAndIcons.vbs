'********************************************************************
'*
'*  Name:            CSI_ExtractMSIGUIDAndIcons.vbs
'*  Author:          Darwin Sanoy
'*  Updates:         http://csi-windows.com/toolkit/csi-extractmsiguidandicons
'*  Bug Reports &
'   Enhancement Req: http://CSI-Windows.com/about/contact-us
'*
'*  Built/Tested On: Windows 7 x64
'*  Should work On:  Windows XP or later 
'*
'*  COPYRIGHT NOTICE:  This script is Copyrighted by Synaptic Fireworks, LLC
'*
'*    This copyright notice and all comments in the script must remain intact.
'* 
'*    For publicly available scripts:
'*    If you downloaded this script from CSI-Windows.com or DesktopEngineer.com
'*    then you may use it in your organization.
'* 
'*    For privately scripts (including enhanced versions of public scripts):
'*    If this script is not available publicly and you received it directly 
'*    from CSI-Windows.com as a result of training, a conference or personal 
'*    contact with staff, then you are allowed to use the script in your
'*    organization.
'*
'*    Regardless of this script's public/private availability, 
'*    no public or private redistribution of this code is allowed - this 
'*    includes the entire script or parts of the script code.  This     
'*    includes, but is not limited to email, posting to websites, blogs 
'*    or forums, CDs, flashdrives or any other means.
'*    
'*    Posting links to the script's homepage on CSI-Windows.com is allowed.
'*
'*
'*  Main Function:
'*    Allows easy extraction of icons and product codes from MSI packages for
'*    inclusion in SCCM 2012 Application Catalog
'*   
'*
'*  PLEASE ALSO READ THE WEB INFORMATION ON THIS TOOL FOR A FULL UNDERSTANDING
'*     OF WHAT IT CAN DO: http://csi-windows.com/toolkit/CSI_IsSession
'*
'*  Syntax:
'*     *) Simple run to install.
'*     *) Right click an .MSI and select '
'*
'*  Usage and Notes:
'*    Simple run the script once to install it (no admin required).


'*    By right clicking an MSI and selecting "CSI-Windows.com - Extract GUID and Icons", 
'*     this script allows: 
'*       *) Extraction of the MSI Product Code (a GUID)
'*       *) Location of the MSI icon cache to extract icons using SCCM 2012 console
'*       *) Checking local system to see if package is already installed and open
'*          icon cache if it is.  Present a prompt containing the Product code GUID 
'*          - user clicks CTRL-C to copy it
'*       *) If it is not installed:
'*            1) perform a per-user [no admin rights required] 
'*               ADVERTISE [much faster than admin installs] of the package 
'*               on the local machine
'*            2) Open the icon cache folder.  
'*            3) Present wait prompt so user can extract the icon using SCCM 2012
'*            4) Unadvertise (uninstall) the product when the user is done 
'*               (only if it was not already installed)
'* 
'*  Documentation:   see above
'*
'*  Version:         1.1
'*
'*  Revision History:
'*     03/14/13 - 1.1 - Inital version (Darwin Sanoy)
'*
'*******************************************************************
Option Explicit
Dim fso, ws, Args, Title
Set fso = CreateObject("Scripting.FileSystemObject")
Set ws = CreateObject("Wscript.Shell")
Set Args = WScript.Arguments
Title = "CSI-Windows.com SCCM 2012 MSI GUID and Icon Extraction"

'If script called directly, then install
If Args.Count = 0 Then
  Call Setup
End If

'Disable multiple drag and drop
If Args.Count > 1 Then
  Call Cleanup
End If

Dim ParentFldr
'If a file was dragged to script
On Error Resume Next
Set ParentFldr = fso.GetFile(Args(0))
If Err.Number = 0 Then
  'Call Cleanup
End If
Set ParentFldr = Nothing
On Error GoTo 0

Call DoWork

Call Cleanup

Sub DoWork ()

Dim oMSI,Package,View,Rec, ProductCode

  Dim MSIName : MsiName = WScript.Arguments(0)

  Set oMSI = CreateObject("WindowsInstaller.Installer")
  oMSI.UILevel = 4
  Set Package = oMSI.OpenDatabase(MsiName,0)
  Set View = Package.OpenView("Select `Value` From Property WHERE `Property` ='ProductCode'")
  View.Execute
  Set Rec = View.Fetch
  ProductCode = Rec.StringData(1)
  view.Close
  set View = nothing
  Set Package = nothing


  If Not Rec Is Nothing Then
     Dim seconds,ExecStop, SecondsPerStatusMessageRefresh, Resp, AdvertisedByThisScript, UserResponse
     Seconds = 0
     SecondsPerStatusMessageRefresh = 5
     AdvertisedByThisScript = False
     
     dim windir : windir = ws.ExpandEnvironmentStrings("%windir%")
     dim machinemsicache : machinemsicache = ws.ExpandEnvironmentStrings("%windir%") & "\Installer\" & ProductCode
     dim usermsicache : usermsicache  =  ws.ExpandEnvironmentStrings("%appdata%") & "\Microsoft\Installer\" & ProductCode
     
     Dim IconCacheFolder : IconCacheFolder = """" & usermsicache & "\" & ProductCode & """"

   
     If NOT fso.FolderExists(machinemsicache) AND NOT fso.FolderExists(usermsicache) Then
       oMSI.UILevel = 3
       oMSI.AdvertiseProduct msiname,1
       'oMSI.InstallProduct msiname,"ADVERTISE=ALL ALLUSERS={}"
       AdvertisedByThisScript = True
     End If
      
      Dim imp2, msg2
    
     If fso.FolderExists(machinemsicache) Then 
       IconCacheFolder = machinemsicache

     ElseIF fso.FolderExists(usermsicache) Then 
       IconCacheFolder = usermsicache
     End If
         
      msg2 = "File: " & MsiName &vbcrlf & "Product Code is: " & ProductCode _
      &vbcrlf &vbcrlf & "Press ""CTRL-C"" to copy the Product Code GUID." _
      &vbcrlf &vbcrlf & "Click ""OK"" to open the icon folder." _
      & "Icon Folder: """ & IconCacheFolder & """"
      imp2 = inputbox(msg2, "Product Code",ProductCode)

      ws.Run "EXPLORER.exe /e, """ & IconCacheFolder &  """"
      
      If AdvertisedByThisScript Then
        UserResponse = MsgBox("Click OK to uninstall the advertisement or Cancel to leave it installed." &vbcrlf &vbcrlf _
           , vbOKCancel + vbExclamation, "Uninstall " & msiname)
        If UserResponse = vbOK Then
          'uninstall product
           oMSI.ConfigureProduct ProductCode,65535,2          
        End If
      End IF
 
  End If
  
End Sub

Sub Setup
  'Write Reg Data if not existing or if path is invalid.
  Dim p
  On Error Resume Next
    Dim oFSO
    set oFSO = CreateObject("Scripting.FileSystemObject")
    Dim ScriptFolder
    ScriptFolder = oFSO.GetParentFoldername(wscript.scriptfullname)

    ws.RegWrite "HKEY_CURRENT_USER\Software\Classes\Msi.Package\shell\CSI_ExtractMSIGUIDAndIcons\","CSI-Windows.com - Extract GUID and Icons"
    ws.RegWrite "HKEY_CURRENT_USER\Software\Classes\Msi.Package\shell\CSI_ExtractMSIGUIDAndIcons\command\", "wscript.exe " & chr(34) & wscript.scriptfullname & chr(34) & " " & chr(34) & "%1" & chr(34)
     
    ws.Popup "Setup complete.  Right click on any .MSI in " & _
             "Explorer and select the " & chr(34) & "CSI-Windows.com - Extract GUID and Icons" & chr(34) & _
             " option to create see the product code and locate the icons." & vbcrlf & vbcrlf, , Title, 64 + 4096
  Call Cleanup
End Sub

Sub Cleanup
  Set ws = Nothing
  Set fso = Nothing
  Set Args = Nothing
  WScript.Quit
End Sub  
