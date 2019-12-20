@Echo Off
If /I "%1"=="/?" Goto:about
If /I "%1"=="/h" Goto:about
If /I "%1"=="/help" Goto:about
Goto:Main
:about
echo ===========================================================================================
echo .Synopsis
echo   Open SMSTS.log from any of its standard locations with CMTrace
echo.ChangeLog
echo   2014/08/15 - Chad.Simmons@CatapultSystems.com OR chad@ChadsTech.net - created
echo ===========================================================================================
echo	 
goto:eof

:main

:ConfigureCMTrace
::re-register CMTrace so it does not prompt to always open log files in itself
reg.exe add HKCU\Software\Microsoft\Trace32 /V "Register File Types" /T REG_SZ /D 1 /F
::set CMTrace preferences
reg.exe add HKCU\Software\Microsoft\Trace32 /V Column0 /T REG_SZ /D "2 125" /F
reg.exe add HKCU\Software\Microsoft\Trace32 /V Column1 /T REG_SZ /D "1 90" /F
reg.exe add HKCU\Software\Microsoft\Trace32 /V Column2 /T REG_SZ /D "0 1000" /F
reg.exe add HKCU\Software\Microsoft\Trace32 /V Column3 /T REG_SZ /D "3 0" /F
reg.exe add HKCU\Software\Microsoft\Trace32 /V ColumnState /T REG_SZ /D 4 /F

:GetLogTool
If Exist X:\Windows\System32\CMTrace.exe set LogTool=X:\Windows\System32\CMTrace.exe
If Exist X:\Windows\CMTrace.exe set LogTool=X:\Windows\CMTrace.exe
If Exist X:\Tools\CMTrace.exe set LogTool=X:\Tools\CMTrace.exe
If Exist %~dp0CMTrace.exe set LogTool=%~dp0CMTrace.exe

:OpenSMSTSLog
If Exist X:\Windows\Temp\SMSTSLog\SMSTS.log start %LogTool% X:\Windows\Temp\SMSTSLog\SMSTS.log
If Exist C:\_SMSTaskSequence\Logs\SMSTSLog\SMSTS.log start %LogTool% C:\_SMSTaskSequence\Logs\SMSTSLog\SMSTS.log
If Exist D:\_SMSTaskSequence\Logs\SMSTSLog\SMSTS.log start %LogTool% D:\_SMSTaskSequence\Logs\SMSTSLog\SMSTS.log
If Exist E:\_SMSTaskSequence\Logs\SMSTSLog\SMSTS.log start %LogTool% E:\_SMSTaskSequence\Logs\SMSTSLog\SMSTS.log
If Exist %WinDir%\CCM\Logs\SMSTSLog\SMSTS.log start %LogTool% %WinDir%\CCM\Logs\SMSTSLog\SMSTS.log
If Exist %WinDir%\sysWOW6432\CCM\Logs\SMSTSLog\SMSTS.log start %LogTool% %WinDir%\sysWOW6432\CCM\Logs\SMSTSLog\SMSTS.log
If Exist %WinDir%\CCM\Logs\SMSTS.log start %LogTool% %WinDir%\CCM\Logs\SMSTS.log
If Exist %WinDir%\sysWOW6432\CCM\Logs\SMSTS.log start %LogTool% %WinDir%\sysWOW6432\CCM\Logs\SMSTS.log

:eof