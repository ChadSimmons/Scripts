@echo off
setlocal
If /I "[%1]"=="/h" Goto:about
If /I "[%1]"=="/help" Goto:about
goto:Begin
:about
echo ===========================================================================================
echo .Synopsis
echo    Take a Screenshot
echo .Description
echo    If Greenshot is found, use it as the screen capture tool.
echo       Note: this only works with Windows 32-bit or Windows On Windows.  WinPE x64 does not support WoW.
echo    If Greenshot is not found, find Zoomit and use it as the screen capture tool.
echo .Parameters
echo   [/h] [/help] display this help information
echo .Notes
echo    === Keywords ===
echo    screenshot, screen shot, screen capture, zoomit, greenshot
echo    === References ===
echo    http://deploymentresearch.com/Research/Post/472/Quick-Tip-Use-ZoomIt-to-take-a-screenshot-in-WinPE
echo    === Change Log History ===
echo    2015/08/28 by Chad.Simmons@CatapultSystems.com - Created
echo ===========================================================================================
goto:eof


:FindZoomIt
::If Greenshot is found use it, otherwise attempt to find ZoomIt
If Exist %~dp0GreenShot.exe set myTool=%~dp0GreenShot.exe
If NOT Defined myTool (
   If Exist \Tools\GreenShot\GreenShot.exe set myTool=\Tools\GreenShot\GreenShot.exe
)
If NOT Defined myTool (
   If Exist \Tools\x86\GreenShot.exe set myTool=\Tools\x86\GreenShot.exe
)
If NOT Defined myTool (
   If Exist %~dp0ZoomIt.exe set myTool=%~dp0ZoomIt.exe
)
If NOT Defined myTool (
   If Exist \Tools\ZoomIt.exe set myTool=\Tools\ZoomIt.exe
)
If NOT Defined myTool (
   If Exist \Tools\x64\ZoomIt.exe set myTool=\Tools\x64\ZoomIt.exe
)
If NOT Defined myTool (
   If Exist \Tools\x86\ZoomIt.exe set myTool=\Tools\x86\ZoomIt.exe
)

If NOT Defined myTool goto:ToolNotFound

:AcceptTheLicense
reg.exe ADD HCU\Software\Sysinternals\Zoomit /d EulaAccepted /v 0 /t REG_DW /f

Echo  To perform a screenshot with ZoomIt
Echo  1. Press CTRL+2 which will activate ZoomIt without zooming
Echo  2. Press CTROL+S to save the screen to a location that you specify
Echo.
Echo  To perform a screenshot with Greenshot
Echo  1. Press PrintScreen
Echo.
%myTool%


goto:eof
:ToolNotFound
echo "The screen shot / screen capture utility was not found
goto:eof




:eof