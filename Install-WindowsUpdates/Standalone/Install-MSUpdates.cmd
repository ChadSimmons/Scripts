@echo off
setlocal
set AppTitle=Windows 10 v1809 64-bit Updates
set ServicingStackFile=windows10.0-kb4509095-x64_db55fad56f519812591f059826f4938733ec66da
set CumulativeUpdateFile=windows10.0-kb4507469-x64_5f3dbb0a076f7113a16dbe218b821a9c1589c96a.msu
set dotNETFile1=windows10.0-kb4506990-x64_b08d8cae796e003093469d9ff4559b7464086617.msu
set dotNETFile2=windows10.0-kb4506998-x64_fc6c6f2e21cfddd6305b9ab19026a6789e666eac.msu
set SetupOPT=/quiet /norestart

If /I [%1]==[/h] goto:Help
If /I [%1]==[-h] goto:Help
If /I [%1]==[/help] goto:Help
If /I [%1]==[-help] goto:Help
goto:Begin
:Help
echo ===============================================================================
echo .Synopsis
echo    Install Microsoft Update (MSU format)
echo .Description
echo    Install update and process return code from WUSA.exe
echo .Parameters
echo    [/h] [/help]      display this help information
echo .Notes
echo    === Change Log History ===
echo    2017/05/15 by Chad.Simmons@CatapultSystems.com - Created
echo ================================================================================
:: ===== Process Return Code =====
::0 / 0x0 Success, no reboot required
::1618 / 0x652 Fast Retry
::1641 / 0x669 Soft Reboot required
::1707 / 0x6AB Success, reboot required (hard reboot requested but redirected to soft reboot)
::3010 / 0xBC2 Success, reboot required
::https://docs.microsoft.com/en-us/windows/deployment/update/windows-update-error-reference
::2359301 / 0x00240005 WU_S_REBOOT_REQUIRED: The system must be restarted to complete installation of the update.
::2359302 / 0x00240006 WU_S_ALREADY_INSTALLED: The update to be installed is already installed on the system.
::2359303 / 0x00240007 WU_S_ALREADY_UNINSTALLED: The update to be removed is not installed on the system.
::-2145124343 / 0x80240009 WU_E_OPERATIONINPROGRESS: Another conflicting operation was in progress. Some operations such as installation cannot be performed twice simultaneously.
::-2145124330 / 0x80240016 WU_E_INSTALL_NOT_ALLOWED: Operation tried to install while another installation was in progress or the system was pending a mandatory restart.
::-2145124329 / 0x80240017 WU_E_NOT_APPLICABLE: Operation was not performed because there are no applicable updates.
goto:eof

:Begin
SET Continue=ture
SET SourceDir=%~dp0
SET SourceDir=%SourceDir:~,-1%

:ProcessReturnCode
GOTO EOF

start /wait "Installing %AppTitle% Servicing Stack..." wusa.exe "%SourceDir%\%ServicingStackFile%" %SetupOPT%
REM CALL:ProcessReturnCode %errorlevel%
SET ReturnCode=%errorlevel%
If %ReturnCode%==-2145124343 SET Continue=false
If %ReturnCode%==-2145124330 SET Continue=false
If %ReturnCode%==1707 SET ReturnCode=3010
If %ReturnCode%==2359301 SET ReturnCode=3010
If %ReturnCode%==2359302 SET ReturnCode=0
If %ReturnCode%==2359303 SET ReturnCode=0
If %ReturnCode%==-2145124343 SET ReturnCode=1618
If %ReturnCode%==-2145124330 SET ReturnCode=1641
If %ReturnCode%==-2145124329 SET ReturnCode=0
If %ReturnCode%==3010 SET PendingRestart=true

If %Continue%==true (
	start /wait "Installing %AppTitle% Cumulative Update..." wusa.exe "%SourceDir%\%CumulativeUpdateFile%" %SetupOPT%
	SET ReturnCode=%errorlevel%
	If %ReturnCode%==-2145124343 SET Continue=false
	If %ReturnCode%==-2145124330 SET Continue=false
	If %ReturnCode%==1707 SET ReturnCode=3010
	If %ReturnCode%==2359301 SET ReturnCode=3010
	If %ReturnCode%==2359302 SET ReturnCode=0
	If %ReturnCode%==2359303 SET ReturnCode=0
	If %ReturnCode%==-2145124343 SET ReturnCode=1618
	If %ReturnCode%==-2145124330 SET ReturnCode=1641
	If %ReturnCode%==-2145124329 SET ReturnCode=0
	If %ReturnCode%==3010 SET PendingRestart=true
)

If %Continue%==true (
	start /wait "Installing %AppTitle% .NET Update..." wusa.exe "%SourceDir%\%dotNETFile1%" %SetupOPT%
	SET ReturnCode=%errorlevel%
	If %ReturnCode%==-2145124343 SET Continue=false
	If %ReturnCode%==-2145124330 SET Continue=false
	If %ReturnCode%==1707 SET ReturnCode=3010
	If %ReturnCode%==2359301 SET ReturnCode=3010
	If %ReturnCode%==2359302 SET ReturnCode=0
	If %ReturnCode%==2359303 SET ReturnCode=0
	If %ReturnCode%==-2145124343 SET ReturnCode=1618
	If %ReturnCode%==-2145124330 SET ReturnCode=1641
	If %ReturnCode%==-2145124329 SET ReturnCode=0
	If %ReturnCode%==3010 SET PendingRestart=true
)

If %Continue%==true (
	start /wait "Installing %AppTitle% .NET Update..." wusa.exe "%SourceDir%\%dotNETFile2%" %SetupOPT%
	SET ReturnCode=%errorlevel%
	If %ReturnCode%==-2145124343 SET Continue=false
	If %ReturnCode%==-2145124330 SET Continue=false
	If %ReturnCode%==1707 SET ReturnCode=3010
	If %ReturnCode%==2359301 SET ReturnCode=3010
	If %ReturnCode%==2359302 SET ReturnCode=0
	If %ReturnCode%==2359303 SET ReturnCode=0
	If %ReturnCode%==-2145124343 SET ReturnCode=1618
	If %ReturnCode%==-2145124330 SET ReturnCode=1641
	If %ReturnCode%==-2145124329 SET ReturnCode=0
	If %ReturnCode%==3010 SET PendingRestart=true
)

If %PendingRestart%==true exit /b 3010
exit /b %ReturnCode%