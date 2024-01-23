@echo off
setlocal
If /I [%1]==[/h] goto:Help
If /I [%1]==[-h] goto:Help
If /I [%1]==[/help] goto:Help
If /I [%1]==[-help] goto:Help
goto:Begin
:Help
echo ===============================================================================
echo ===============================================================================
echo .Synopsis
echo    Stage Windows hardware drivers in the driver store
echo .Description
echo    using Robocopy.exe, copy drivers from a Drivers.wim to the script's directory
echo .Functionality
echo    Hardware Driver staging
echo .Parameters
echo    [/h] [/help]      display this help information
echo .Notes
echo    === References and Sources ===
echo    https://learn.microsoft.com/en-us/windows-hardware/drivers/install
echo    https://docs.microsoft.com/en-us/windows-hardware/drivers/devtest/pnputil
echo    https://utilizewindows.com/stage-a-driver-in-windows-7
echo    https://technet.microsoft.com/en-us/library/cc772036.aspx
echo    https://technet.microsoft.com/en-us/library/cc753716.aspx
echo    === Change Log History ===
echo    2023/05/09 by Chad.Simmons@Quisitive.com - Updated help section
echo    2020/10/01 by Chad.Simmons@CatapultSystems.com - Added quotes to all file paths
echo    2020/08/28 by Chad.Simmons@CatapultSystems.com - Created
echo ================================================================================
goto:eof

:Begin
SET SourceDir=%~dp0
SET SourceDir=%SourceDir:~,-1%

If Exist "%SourceDir%\Drivers.wim" goto:MountWIM
SET StageDir=%SourceDir%
GOTO:ExtractDrivers

:MountWIM
SET StageDir=%SystemDrive%\_DriversWIM
mkdir "%StageDir%"
DISM.exe /Mount-Wim /WimFile:"%SourceDir%\Drivers.wim" /index:1 /MountDir:"%StageDir%" /ReadOnly

:ExtractDrivers
If Exist "%SourceDir%\Drivers.wim" Robocopy.exe "%StageDir%" "%SourceDir%" /e
SET rc=%errorlevel%
SET rc=0

:END
If Exist "%SourceDir%\Drivers.wim" DISM.exe /Unmount-Wim /MountDir:"%StageDir%" /Discard
If Exist "%StageDir%" RMDir "%StageDir%"

EXIT /b %rc%