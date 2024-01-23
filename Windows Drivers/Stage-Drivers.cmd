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
echo    using PNPUtil.exe, add hardware drivers for Microsoft Windows 11 / 10 / 8.1 / 8 / 7 to the Windows Drivers Store
echo    If Drivers.wim exists, mount it before running PNPUtil.exe and unmount it afterwards
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
echo    2023/05/10 by Chad.Simmons@Quisitive.com - Updated help section; added PnPutil logging; Echo return code(s)
echo    2020/10/01 by Chad.Simmons@CatapultSystems.com - Added quotes to all file paths
echo    2020/08/28 by Chad.Simmons@CatapultSystems.com - Created
echo ================================================================================
goto:eof

:Begin
SET SourceDir=%~dp0
SET SourceDir=%SourceDir:~,-1%

If Exist "%SourceDir%\Drivers.wim" goto:MountWIM
SET StageDir=%SourceDir%
GOTO:InstallDrivers

:MountWIM
SET StageDir=%SystemDrive%\_DriversWIM
mkdir "%StageDir%"
DISM.exe /Mount-Wim /WimFile:"%SourceDir%\Drivers.wim" /index:1 /MountDir:"%StageDir%" /ReadOnly
GOTO:InstallDrivers


:InstallDrivers
REM drivers in the mounted WIM are being injected into the offline image
REM DISM.exe /Image:%OSDTargetSystemDrive%\ /Add-Driver /Driver:%StageDir% /Recurse /logpath:%_SMSTSMDataPath%\Drivers\dism.log

REM Export an inventory of current drivers
PowerShell.exe -NoProfile -Command "Get-WmiObject Win32_PnPSignedDriver | Select-Object Manufacturer, DriverProviderName, FriendlyName, DeviceName, DriverVersion, DriverDate, InfName, IsSigned, DeviceID, Description | Sort-Object DeviceID | Export-Csv -NoTypeInformation -Path $($env:Temp + '\DriverInventory.before.tmp'); Copy-Item -Path $($env:Temp + '\DriverInventory.before.tmp') -Destination $('C:\Windows\CCM\Logs\DriverInventory.'+$(Get-Date -Format 'yyyyMMdd_HHmmss')+'.csv')"
REM PnPutil.exe /enum-drivers > "%Temp%\Enum-Drivers_BeforeImport.log"

REM install/update drivers on any matching devices
PnPutil.exe /add-driver "%StageDir%\*.inf" /subdirs /install >> "%WinDir%\CCM\Logs\Stage-Drivers.log"
SET rc=%errorlevel%
echo PNPUtil.exe completed with exit code %rc% >> "%WinDir%\CCM\Logs\Stage-Drivers.log"

REM Export an inventory of drivers
PowerShell.exe -NoProfile -Command "Get-WmiObject Win32_PnPSignedDriver | Select-Object Manufacturer, DriverProviderName, FriendlyName, DeviceName, DriverVersion, DriverDate, InfName, IsSigned, DeviceID, Description | Sort-Object DeviceID | Export-Csv -NoTypeInformation -Path $($env:Temp + '\DriverInventory.after.tmp'); Copy-Item -Path $($env:Temp + '\DriverInventory.after.tmp') -Destination $('C:\Windows\CCM\Logs\DriverInventory.'+$(Get-Date -Format 'yyyyMMdd_HHmmss')+'.csv')"
REM PnPutil.exe /enum-drivers > "%Temp%\Enum-Drivers_AfterImport.log"

:UnmountWIM
If Exist "%SourceDir%\Drivers.wim" DISM.exe /Unmount-Wim /MountDir:"%StageDir%" /Discard
If Exist "%StageDir%" RMDir "%StageDir%"


:END
REM TODO: Create log of exit actions, code, etc.

REM https://www.sysmansquad.com/2020/05/15/modern-driver-management-with-the-administration-service
If [%rc%]==[259] SET rc=3010

REM if the before and after driver inventory has changed a reboot MAY be required, thus return success pending restart
FC.exe "%TEMP%\DriverInventory.before.tmp" "%TEMP%\DriverInventory.after.tmp"
If [%errorlevel%]==[1] SET rc=3010
del /q "%TEMP%\DriverInventory.before.tmp"
del /q "%TEMP%\DriverInventory.after.tmp"

echo Script %~nx0 completed with exit code %rc% >> "%WinDir%\CCM\Logs\Stage-Drivers.log"
EXIT /b %rc%