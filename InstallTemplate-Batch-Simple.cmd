@echo off
setlocal
set AppTitle=My Application Mame
set SetupFile=My Application EXE  (or MSIEXEC.exe  or  WUSA.exe)
set SetupOPT=/quiet /norestart /log "%WinDir%\Logs\%AppTitle%.log"

If /I [%1]==[/?] goto:Help
If /I [%1]==[-?] goto:Help
If /I [%1]==[/h] goto:Help
If /I [%1]==[-h] goto:Help
If /I [%1]==[/help] goto:Help
If /I [%1]==[-help] goto:Help
goto:Begin
:Help
echo ===============================================================================
echo .Synopsis
echo    Install %AppTitle%
echo .Description
echo    Install software, updates, and configurations
echo .Functionality
echo    Software installation and configuration
echo .Parameters
echo    [/h] [/help]      display this help information
echo .Notes
echo    === References and Sources ===
echo    description: http://my.url
echo    === Change Log History ===
echo    2015/09/23 by Chad.Simmons@CatapultSystems.com - Created
echo ================================================================================
goto:eof

:Begin
SET SourceDir=%~dp0
SET SourceDir=%SourceDir:~,-1%
SET SetupType=%SetupFile:~-4%

If [%SetupType%]==[.exe] start /wait "Installing %AppTitle%..." "%SourceDir%\%SetupEXE%" %SetupOPT%
If [%SetupType%]==[.msi] start /wait "Installing %AppTitle%..." msiexec.exe /i "%SourceDir%\%SetupFile%" %SetupOPT%
If [%SetupType%]==[.msu] start /wait "Installing %AppTitle%..." wusa.exe "%SourceDir%\%SetupFile%" %SetupOPT%
If [%SetupType%]==[.vbs] start /wait "Installing %AppTitle%..." cscript.exe "%SourceDir%\%SetupFile%" %SetupOPT%
If [%SetupType%]==[.ps1] start /wait "Installing %AppTitle%..." PowerShell.exe -ExecutionPolicy Bypass -file "%SourceDir%\%SetupFile%" %SetupOPT%

exit /b %errorlevel%
:eof