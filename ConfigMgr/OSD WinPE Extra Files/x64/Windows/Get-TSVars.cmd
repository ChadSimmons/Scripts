@echo off
setlocal
If /I "[%1]"=="/h" Goto:about
If /I "[%1]"=="/help" Goto:about
goto:Begin
:about
echo ===========================================================================================
echo .Synopsis
echo   Export MDT/SCCM Task Sequence Variables to a file and open the output with CMTrace
echo .Description
echo .Parameters
echo   [/h] [/help] display this help information
echo .Notes
echo    === Keywords ===
echo    screenshot, screen shot, screen capture, zoomit, greenshot
echo    === References ===
echo    http://deploymentresearch.com/Research/Post/472/Quick-Tip-Use-ZoomIt-to-take-a-screenshot-in-WinPE
echo    === Change Log History ===
echo    2014/09/19 by Chad.Simmons@CatapultSystems.com OR chad@ChadsTech.net - Created
echo ===========================================================================================
goto:eof

:Begin
setlocal
set customScripts=%SystemDrive%\Tools\Scripts

:ConfigureCMTrace
::re-register CMTrace so it does not prompt to always open log files in itself
reg.exe add HKCU\Software\Microsoft\Trace32 /V "Register File Types" /T REG_SZ /D 1 /F
::set CMTrace preferences
reg.exe add HKCU\Software\Microsoft\Trace32 /V Column0 /T REG_SZ /D "2 125" /F
reg.exe add HKCU\Software\Microsoft\Trace32 /V Column1 /T REG_SZ /D "1 170" /F
reg.exe add HKCU\Software\Microsoft\Trace32 /V Column2 /T REG_SZ /D "0 1000" /F
reg.exe add HKCU\Software\Microsoft\Trace32 /V Column3 /T REG_SZ /D "3 0" /F
reg.exe add HKCU\Software\Microsoft\Trace32 /V ColumnState /T REG_SZ /D 4 /F

:GetLogTool
If Exist %SystemDrive%\Windows\System32\CMTrace.exe set LogTool=%SystemDrive%\Windows\System32\CMTrace.exe
If Exist %SystemDrive%\Windows\CMTrace.exe set LogTool=%SystemDrive%\Windows\CMTrace.exe
If Exist %SystemDrive%\Tools\CMTrace.exe set LogTool=%SystemDrive%\Tools\CMTrace.exe
If Exist %~dp0CMTrace.exe set LogTool=%~dp0CMTrace.exe

:OpenSMSTSLog
:PS1
If NOT Exist %customScripts%\OutputTSVariables.ps1 goto:VBS
Set PSexe=%SystemDrive%\Windows\System32\WindowsPowerShell\v1.0\PowerShell.exe
If NOT Exist %PSexe% goto:VBS
%PSexe% -ExecutionPolicy Bypass -file "%customScripts%\OutputTSVariables.ps1"
echo .
echo .
echo execute "%LogTool% %SystemDrive%\Windows\Temp\SMSTSLog\OutputTSVariables.ps1.log" to view this version of the file.
echo .
echo .

:VBS
If NOT Exist %customScripts%\OutputTSVariables.vbs goto:WSF
echo Exporting Task Sequence Variables using OutputTSVariables.vbs to %SystemDrive%\TSVars.log ...
if Exist %SystemDrive%\TSVars.log del %SystemDrive%\TSVars.log
cscript.exe /nologo "%customScripts%\OutputTSVariables.vbs" > %SystemDrive%\TSVars.log
start %LogTool% %SystemDrive%\TSVars.log

:WSF
If NOT Exist %customScripts%\OutputTSVariables.wsf goto:END
echo Exporting Task Sequence Variables using OutputTSVariables.wsf to %SystemDrive%\TSVars.txt ...
If Exist %SystemDrive%\TSVars.txt del %SystemDrive%\TSVars.txt
cscript.exe /nologo "%customScripts%\OutputTSVariables.wsf" > %SystemDrive%\TSVars.txt
echo .
echo .
echo execute "%LogTool% %SystemDrive%\TSVars.txt" to view this version of the file.
echo .
echo .

:END

:EOF