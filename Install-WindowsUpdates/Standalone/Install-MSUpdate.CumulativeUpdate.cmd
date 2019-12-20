@echo off
setlocal
set AppTitle=Windows 10 v1809 Cumulative Update
set SetupFile=windows10.0-kb4507469-x64_5f3dbb0a076f7113a16dbe218b821a9c1589c96a.msu
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
goto:eof

:Begin
SET SourceDir=%~dp0
SET SourceDir=%SourceDir:~,-1%

start /wait "Installing %AppTitle%..." wusa.exe "%SourceDir%\%SetupFile%" %SetupOPT%
set ReturnCode=%errorlevel%

:: ===== Process Return Code =====
::0 / 0x0 Success, no reboot required
::1618 / 0x??? Fast Retry
::1641 / 0x??? Soft Reboot required
::1707 / 0x??? Sucess, reboot required (hard reboot requested but redirected to soft reboot)
::3010 / 0x??? Success, reboot required
::2359301 / 0x??? WU_S_REBOOT_REQUIRED: The system must be restarted to complete installation of the update.
::2359302 / 0x??? WU_S_ALREADY_INSTALLED: The update to be installed is already installed on the system.
::2359303 / 0x??? WU_S_ALREADY_UNINSTALLED: The update to be removed is not installed on the system.
::-2145124343 / 0x??? WU_E_OPERATIONINPROGRESS: Another conflicting operation was in progress. Some operations such as installation cannot be performed twice simultaneously.
::-2145124330 / 0x??? WU_E_INSTALL_NOT_ALLOWED: Operation tried to install while another installation was in progress or the system was pending a mandatory restart.
::-2145124329 / 0x??? WU_E_NOT_APPLICABLE: Operation was not performed because there are no applicable updates.

If %ReturnCode%==1707 set ReturnCode=3010
If %ReturnCode%==2359301 set ReturnCode=3010
If %ReturnCode%==2359302 set ReturnCode=0
If %ReturnCode%==2359303 set ReturnCode=0
If %ReturnCode%==-2145124343 set ReturnCode=1618
If %ReturnCode%==-2145124330 set ReturnCode=1641
If %ReturnCode%==-2145124329 set ReturnCode=0

exit /b %ReturnCode%