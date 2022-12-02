@ECHO off
SETLOCAL
::SetupTitle is the Name of the Microsoft Update.
::SetupFile is <file name.msu> of the Microsoft Update.  If not specified, the script with accept a file name form the command line.
::  If neither specified or from command line, the most recently modified MSU file in the script directory will be used
SET SetupTitle=
SET SetupFile=
SET SetupOPT=/quiet /norestart

If /I [%1]==[/h] GOTO:Help
If /I [%1]==[-h] GOTO:Help
If /I [%1]==[/help] GOTO:Help
If /I [%1]==[-help] GOTO:Help
GOTO:Begin
:Help
ECHO ===============================================================================
ECHO .Synopsis
ECHO    Install Microsoft Update (MSU format)
ECHO .Description
ECHO    Install update and process return code from WUSA.exe
ECHO .Parameter
ECHO    [/h] [/help]      display this help information
ECHO .Parameter
ECHO    [file name.msu]   Optional command line parameter of a MSU file in the same folder which should be installed
ECHO .Notes
ECHO    === Change Log History ===
ECHO    2020/08/03 by Chad.Simmons@CatapultSystems.com - updated return code processing, added auto MSU detection and command line parameter for MSU
ECHO    2017/05/15 by Chad.Simmons@CatapultSystems.com - Created
ECHO ================================================================================
GOTO:EOF
:Begin
SET SourceDir=%~dp0
SET SourceDir=%SourceDir:~,-1%

::If SetupFile is not specified set SetupFile to the most recently modified MSU file in the SourceDir
IF NOT [%1]==[] SET SetupFile=%1
IF [%SetupFile%]==[] FOR /f %%a IN ('dir /b /a-d /od *.msu') DO SET SetupFile=%%a
IF [%SetupFile%]==[] EXIT /b 2
IF ["%SetupTitle%"]==[""] SET SetupTitle=%SetupFile%
ECHO "Installing [%SetupTitle%].  Running [%SetupFile%]"
START /wait "Installing %SetupTitle%..." %WinDir%\System32\WUSA.exe "%SourceDir%\%SetupFile%" %SetupOPT%
SET ReturnCode=%errorlevel%
:: ===== Process Return Code =====
::    Decimal / Hex        ERROR_NAME: Error description
::          0 / 0x0        ERROR_SUCCESS: Success, no reboot required
::       1618 / 0x652      ERROR_INSTALL_ALREADY_RUNNING: Another installation is already in progress. Complete that installation before proceeding with this install. (ConfigMgr: Fast Retry)
::       1641 / 0x669      ERROR_SUCCESS_REBOOT_INITIATED: The installer has initiated a restart. This message is indicative of a success. (ConfigMgr: Hard Reboot)
::                            The requested operation completed successfully. The system will be restarted so the changes can take effect.
::       1707 / 0x6ab      Installation operation completed successfully
::       3010 / 0xbc2      ERROR_SUCCESS_REBOOT_REQUIRED: Success, soft reboot required
::    2359301 / 0x240005   WU_S_REBOOT_REQUIRED: The system must be restarted to complete installation of the update.
::    2359302 / 0x240006   WU_S_ALREADY_INSTALLED: The update to be installed is already installed on the system.
::    2359303 / 0x240007   WU_S_ALREADY_UNINSTALLED: The update to be removed is not installed on the system.
::-2145124343 / 0x80240009 WU_E_OPERATIONINPROGRESS: Another conflicting operation was in progress. Some operations such as installation cannot be performed twice simultaneously.
::-2145124330 / 0x80240016 WU_E_INSTALL_NOT_ALLOWED: Operation tried to install while another installation was in progress or the system was pending a mandatory restart.
::-2145124329 / 0x80240017 WU_E_NOT_APPLICABLE: Operation was not performed because there are no applicable updates.
If %ReturnCode%==1707 SET ReturnCode=0
If %ReturnCode%==2359301 SET ReturnCode=3010
If %ReturnCode%==2359302 SET ReturnCode=0
If %ReturnCode%==2359303 SET ReturnCode=0
If %ReturnCode%==-2145124343 SET ReturnCode=1618
If %ReturnCode%==-2145124330 SET ReturnCode=1618
If %ReturnCode%==-2145124329 SET ReturnCode=0
EXIT /b %ReturnCode%