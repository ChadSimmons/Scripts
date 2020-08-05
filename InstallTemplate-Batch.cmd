@echo off
setlocal
set AppTitle=myApplication Name
Call:Get-CommonCommandLineOptions %*
If NOT [%doHelp%]==[True] goto:Begin
::#region    Help
echo ###############################################################################
echo .SYNOPSIS
echo	ScriptFileName.cmd
echo	Software installation and configuration of %AppTitle%
echo .DESCRIPTION
echo 	  A detailed description of the function or script. This keyword can be used only once in each topic.
echo .PARAMETER
echo    [/debug]          display debug information
echo    [/verbose]        display additional information
echo    [/h] [/help]      display this help information
echo .PARAMETER <name>
echo 	  Specifies <xyz>
echo .EXAMPLE
echo 	  ScriptFileName.cmd -Parameter1
echo 	  A sample command that uses the function or script, optionally followed by sample output and a description. Repeat this keyword for each example.
echo .LINK
echo 	  Link Title: http://contoso.com/ScriptFileName.txt
echo 	  The name of a related topic. The value appears on the line below the .LINE keyword and must be preceded by a comment symbol (#) or included in the comment block.
echo 	  Repeat the .LINK keyword for each related topic.
echo 	  This content appears in the Related Links section of the help topic.
echo    The Link keyword content can also include a Uniform Resource Identifier (URI) to an online version of the same help topic. The online version  opens when you use the Online parameter of Get-Help. The URI must begin with "http" or "https".
echo .NOTES
echo    This script is maintained at https://github.com/ChadSimmons/Scripts
echo 	  Additional information about the function or script.
echo 	  ========== Keywords ==========
echo    Keywords: ???
echo 	  ========== Change Log History ==========
echo 	  - yyyy/mm/dd by Chad Simmons - Modified $ChangeDescription$
echo 	  - yyyy/mm/dd by Chad.Simmons@CatapultSystems.com - Created
echo 	  - yyyy/mm/dd by Chad@ChadsTech.net - Created
echo 	  === To Do / Proposed Changes ===
echo 	  - TODO: None
echo 	  ========== Additional References and Reading ==========
echo 	  - <link title>: https://domain.url
echo ###############################################################################
goto:eof
::#endregion Help

::#region    Main script
:Begin
Call:Get-Settings
For %%a in (%*) Do (
	If /I [%%a]==[/Custom1] set Custom1=CustomText
	If /I [%%a]==[/Custom2] goto:Custom2
)
:Install
Set action=Installing %AppTitle%
Call:LogMsg "Installing %AppTitle%"
start /wait "%action%" "%SourceDir%\files\%SetupEXE%" -s -w -clone_wait -f1"%SourceDir%\files\setup.iss" -f2"%WinDir%\Logs\%AppTitle%.log"
set rc=%errorlevel%
If Defined doDebug Call:LogMsgWithPause "%action% return code is %rc%"

Call:LogMsg "Copy shortcut to default user"
xcopy /y "%commonStartMenu%\Programs\[Company Name]\[Product Name]\[Product Name].lnk" "%defaultUserStartMenu%"

If Exist "%commonDesktop%\[Product Name].lnk" (
	Call:LogMsg "Delete desktop shortcut"
	del /q  "%commonDesktop%\[Product Name].lnk"
)
::#endregion Main script

::#region    Template Code
:: ========== Only Template code below here =======================================================
goto:end

:Get-Settings
set bShowMsg=False
If Defined doDebug set bShowMsg=True
If Defined doVerbose set bShowMsg=True
If %bShowMsg%==True echo.
Call:LogMsg "========= Running %~f0 =========="
Call:LogMsg "Batch Installer Template version 2015.03.11"
Call:LogMsg "Getting Settings..."
::Get-CurrentDirectoryWithoutBackslash
SET SourceDir=%~dp0
SET SourceDir=%SourceDir:~,-1%
::Get-OSarchitecture
If Defined ProgramFiles(x86) (set arch=64) else (set arch=32)
:: set ProgramFiles32=%ProgramFiles%
:: Does not work :: If Defined ProgramFiles(x86) set ProgramFiles32=%SystemDrive%\Program Files (x86)
:: Does not work :: If Defined ProgramFiles(x86) set ProgramFiles32=%ProgramFiles% (x86^^)
:: Does not work :: If Defined ProgramFiles(x86) set ProgramFiles32=%SystemDrive%\Program Files ^(x86^)
:: Does not work :: If Defined ProgramFiles(x86) for /F "tokens=4*" %%a in ('reg.exe query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion" /v "ProgramFilesDir (x86)" 2^>NUL ^| find "REG_SZ"') do set ProgramFiles32=%%b
::Get-LogsDir
If NOT Exist "%WinDir%\Logs" (
	Call:LogMsg "Creating folder '%WinDir%\Logs'"
	mkdir "%WinDir%\Logs" >nul
	)
set LogsDir=%WinDir%\Logs\Software
If NOT Exist "%LogsDir%" (
	Call:LogMsg "Creating folder '%LogsDir%'"
	mkdir "%LogsDir%" >nul
	)
set "commonLog=%WinDir%\Logs\Install.log"
::Get-commonUserStartMenu
for /F "tokens=4*" %%a in ('reg.exe query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders" /v "Common Start Menu" 2^>NUL ^| find "REG_SZ"') do set commonStartMenu=%%b
::Get-commonUserDesktop
for /F "tokens=3*" %%a in ('reg.exe query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders" /v "Common Desktop" 2^>NUL ^| find "REG_SZ"') do set commonDesktop=%%b
::Get-defaultUserStartMenu
:: Not working due to REG_EXPAND_SZ :: for /F "tokens=2*" %%a in ('reg.exe query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList" /v "Default" 2^>NUL ^| find "REG_EXPAND_SZ"') do set defaultUserStartMenu=%%b\AppData\Roaming\Microsoft\Windows\Start Menu
If Exist "%SystemDrive%\Documents and Settings\Default User\Start Menu" set defaultUserStartMenu=%SystemDrive%\Documents and Settings\Default User\Start Menu
If Exist "%SystemDrive%\Users\Default\AppData\Roaming\Microsoft\Windows\Start Menu" set defaultUserStartMenu=%SystemDrive%\Users\Default\AppData\Roaming\Microsoft\Windows\Start Menu
::Get-defaultUserDesktop
:: Not working due to REG_EXPAND_SZ :: for /F "tokens=2*" %%a in ('reg.exe query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList" /v "Default" 2^>NUL ^| find "REG_EXPAND_SZ"') do set defaultUserDesktop=%%b\Desktop
If Exist "%SystemDrive%\Documents and Settings\Default User\Desktop" set defaultUserDesktop=%SystemDrive%\Documents and Settings\Default User\Desktop
If Exist "%SystemDrive%\Users\Default\Desktop" set defaultUserDesktop=%SystemDrive%\Users\Default\Desktop
::Get-ProfileRootDir
:: Not working due to REG_EXPAND_SZ :: for /F "tokens=2*" %%a in ('reg.exe query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList" /v "ProfilesDirectory" 2^>NUL ^| find "REG_EXPAND_SZ"') do set ProfileRootDir=%%b
If Exist "%SystemDrive%\Documents and Settings\All Users" set ProfileRootDir=%SystemDrive%\Documents and Settings
If Exist "%SystemDrive%\Users\Public" set ProfileRootDir=%SystemDrive%\Users
::Get-MyDesktop
for /F "tokens=2*" %%a in ('reg.exe query "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders" /v "Desktop" 2^>NUL ^| find "REG_SZ"') do set MyDesktop=%%b
::Get-MyStartMenu
for /F "tokens=3*" %%a in ('reg.exe query "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders" /v "Start Menu" 2^>NUL ^| find "REG_SZ"') do set MyStartMenu=%%b
::Get-DateTime
for /F "usebackq tokens=1,2 delims==" %%i in (`wmic os get LocalDateTime /VALUE 2^>NUL`) do if '.%%i.'=='.LocalDateTime.' set ldt=%%j
set YYYYMMDD_HHMM=%ldt:~0,8%_%ldt:~8,4%
set DateTime=%ldt:~0,4%/%ldt:~4,2%/%ldt:~6,2% %ldt:~8,2%:%ldt:~10,2%

If %bShowMsg%==True (
	echo off
	echo For Help and About, run %~f0 /h
 	echo DP0 Dir              is %~dp0
 	echo Current Dir          is %__CD__%
 	echo SourceDir            is %SourceDir%
	echo AppTitle             is %AppTitle%
	echo LogsDir              is %LogsDir%
	echo commonLog            is %commonLog%
 	echo The Date and Time    is %DateTime%
 	echo YYYYMMDD_HHMM        is %YYYYMMDD_HHMM%
 	echo Arch                 is %Arch%
 	echo ProgramFiles         is %ProgramFiles%
	echo ProgramW6432         is %ProgramW6432%
 	echo commonStartMenu      is %commonStartMenu%
 	echo commonDesktop        is %commonDesktop%
 	echo defaultUserStartMenu is %defaultUserStartMenu%
 	echo defaultUserDesktop   is %defaultUserDesktop%
 	echo MyStartMenu          is %MyStartMenu%
 	echo MyDesktop            is %MyDesktop%
 	echo ProfileRootDir       is %ProfileRootDir%
	echo      =====================================================================
)
goto:eof

:Get-CommonCommandLineOptions
:: .Synopsis - Process predefined command line options
:: .Parameter1 - %* which is the entire list of command line parameters passed to this batch file
:: TODO: use findstr /r as an alternative to this entire function
For %%a in (%*) Do (
	If /I [%%a]==[/debug] set doDebug=True
	If /I [%%a]==[/verbose] set doVerbose=True
	If /I [%%a]==[/h] set doHelp=True
	If /I [%%a]==[/help] set doHelp=True
	If /I [%%a]==[-debug] set doDebug=True
	If /I [%%a]==[-verbose] set doVerbose=True
	If /I [%%a]==[-h] set doHelp=True
	If /I [%%a]==[-help] set doHelp=True
)
If DEFINED doDebug echo ========== Debugging Enabled ==========
If DEFINED doVerbose echo ========== Verbose Enabled ==========
goto:eof

:LogMsg
:: .Synopsis - Display a message and optionally pause afterwards
:: .Parameter1 - [mandatory] Message to be logged (must be double-quoted if it contains spaces)
If [%1]==[] goto:eof
If %bShowMsg%==True echo %~1
goto:eof

:LogMsgWithPause
:: .Synopsis - Display a message and optionally pause afterwards
:: .Parameter1 - [mandatory] Message to be logged (must be double-quoted if it contains spaces)
If [%1]==[] goto:eof
If %bShowMsg%==True echo %~1
pause
goto:eof

:end
@echo off
If NOT Defined RC set RC=0
Call:LogMsg "Logging execution to '%commonLog%'"
Echo %DateTime%;%AppTitle%;%RC% >> "%commonLog%"
Call:LogMsg "Return Code is %RC%"
Call:LogMsg "========= Completed %~f0 =========="
If Defined doDebug pause
If %bShowMsg%==True echo.
exit /b %RC%
:eof
::#endregion Template Code