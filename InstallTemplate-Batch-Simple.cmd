@echo off
setlocal
set AppTitle=My Application Mame
set SetupFile=My Application EXE  (or MSIEXEC.exe  or  WUSA.exe)
set SetupOPT=/quiet /norestart /log "%WinDir%\Logs\%AppTitle%.log"
REM ####################################################################################################################
If /I "%1"=="/h" goto:about
If /I "%1"=="/help" goto:about
goto:main
:about
echo ###################################################################################################################
echo .Synopsis
echo     ScriptFileName.cmd
echo     Install %AppTitle%
echo .Description
echo     Install software, updates, and configurations
echo .Parameters
echo    [/h] [/help]      display this help information
echo .Parameter <Parameter-Name>
echo     The description of a parameter
echo .Example
echo     ScriptFileName.cmd Parameter1
echo     A sample command that uses the function or script, optionally followed by sample output and a description
echo .Link
echo     The name and/or URL of a related topic
echo .NOTES
echo     This script is maintained at ??????????????????????????????????????????????????????????????????????????????????
echo     Additional information about the function or script.
echo     ========== Keywords =========================
echo     Keywords: ???
echo     ========== Change Log History ===============
echo     - YYYY/MM/DD by name@contoso.com - ~updated description~
echo     - YYYY/MM/DD by name@contoso.com - created
echo     ========== To Do / Proposed Changes =========
echo     - #TODO: None
echo     ===== Additional References and Reading =====
echo     - <link title>: https://domain.url
echo ###################################################################################################################
goto:eof
:main
set ScriptPath=%~dp0
set ScriptPath=%ScriptPath:~,-1%
SET SetupType=%SetupFile:~-4%

If [%SetupType%]==[.exe] start /wait "Installing %AppTitle%..." "%ScriptPath%\%SetupEXE%" %SetupOPT%
If [%SetupType%]==[.msi] start /wait "Installing %AppTitle%..." msiexec.exe /i "%ScriptPath%\%SetupFile%" %SetupOPT%
If [%SetupType%]==[.msu] start /wait "Installing %AppTitle%..." wusa.exe "%ScriptPath%\%SetupFile%" %SetupOPT%
If [%SetupType%]==[.vbs] start /wait "Installing %AppTitle%..." cscript.exe "%ScriptPath%\%SetupFile%" %SetupOPT%
If [%SetupType%]==[.ps1] start /wait "Installing %AppTitle%..." PowerShell.exe -ExecutionPolicy Bypass -file "%ScriptPath%\%SetupFile%" %SetupOPT%

exit /b %errorlevel%
:eof