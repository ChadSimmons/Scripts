@echo off
setlocal
set AppTitle=Backup To WIM

Call:Get-CommonCommandLineOptions %*
If NOT [%doHelp%]==[True] goto:Begin
echo ===============================================================================
echo .Synopsis
echo    Install %AppTitle%
echo .Description
echo    Backup Drive/Folder to WIM keeping multiple backups
echo .Functionality
echo    Software installation and configuration
echo .Parameter 1
echo    BackupType [WIM|7z|ALL]
echo .Parameter 2
echo    BackupName - Creates a WIM file with this name
::TODO:: echo .Parameter 3
::TODO:: echo    SourceDir - Root folder to backup
::TODO:: echo .Parameter 4
::TODO:: echo    TargetDir - Folder to create the WIM file in
::TODO:: echo .Parameter
::TODO:: echo    [/h] [/help]      display this help information
echo .Example
echo    Backup-ToWIM.cmd WIM USB_SecurityTools
echo .Example
echo    Backup-ToWIM.cmd ALL USB_SecurityTools
echo .Notes
echo    === References and Sources ===
echo    ???
echo    === Change Log History ===
echo    YYYY/MM/DD by Chad@ChadsTech.net - updated ???
echo    YYYY/MM/DD by Chad@ChadsTech.net - Created
echo ================================================================================
goto:eof


if NOT [%1]==[] set /p SourceDir=%~dp0
if NOT [%2]==[] set /p BackupName=Backup Name

echo SourceDir is %SourceDir%
echo BackupName is %BackupName%
exit /b

set SourceDir=%~dp0
set TargetDir=B:\Backup\
Set TargetDir=%TargetDir:~,-1%
::folder for 2nd backup location.  comment out to skip
::Set BackupDir=A:\Backup\

echo Backuping '%BackupName%'
echo Source location      '%SourceDir%'
echo Destination location '%TargetDir%'
if Defined BackupDir echo 2nd Backup location  '%BackupDir%'


::set the default backup type to WIM only, overwrite via the command line
Set BackupTypes=WIM
If NOT "%1"=="" Set BackupTypes=%1

Call:GetDates
if %BackupTypes%==WIM Call:Backup-WIM
if %BackupTypes%==7z  Call:Backup-7z
if %BackupTypes%==all Call:Backup-WIM
if %BackupTypes%==all Call:Backup-7z
endlocal
goto:eof

:GetDates
::http://stackoverflow.com/questions/203090/how-to-get-current-datetime-on-windows-command-line-in-a-suitable-format-for-us
for /F "usebackq tokens=1,2 delims==" %%i in (`wmic os get LocalDateTime /VALUE 2^>NUL`) do if '.%%i.'=='.LocalDateTime.' set ldt=%%j
set YYYYMMDD_HHMM=%ldt:~0,8%_%ldt:~8,4%
set YYYYMMDD=%ldt:~0,8%
set YYYY=%ldt:~0,4%
set MM=%ldt:~4,2%
set DD=%ldt:~6,2%
set hh=%ldt:~8,2%
set nn=%ldt:~10,2%
set ss=%ldt:~12,2%
echo the date and time is %YYYYMMDD_HHMM%
goto:eof

:Backup-7z
echo compress with 7-zip command line
If Exist "%TargetDir%\7za.exe" Set Tool="%TargetDir%\7za.exe"
If Exist "%~dp07za.exe" Set Tool="%~dp07za.exe"
%Tool% a -mx4 -t7z -r -xr!*.tmp -xr!thumbs.db "%TargetDir%\%BackupName%-%yyyy%-%mm%-%dd%.7z" "%SourceDir%\*.*" 
Call:MakeCopy *.7z
goto:eof

:Backup-WIM
If Exist "%TargetDir%\Backup-ToWIM.ini" Set ExcFile=%TargetDir%\Backup-ToWIM.ini
If Exist "%~dp0Backup-ToWIM.ini" Set ExcFile=%~dp0Backup-ToWIM.ini
If Exist "%TargetDir%\%BackupName%.ini" Set ExcFile=%TargetDir%\%BackupName%.ini
If Exist "%~dp0%BackupName%.ini" Set ExcFile=%~dp0%BackupName%.ini

echo compress with ImageX (if available) or DISM command line
set method=CAPTURE
if exist "%TargetDir%\%BackupName%.wim" set method=APPEND

::TODO:: Use DISM if OS is Windows 7 or newer and fall back to ImageX
If Exist "%TargetDir%\imagex.exe" Set Tool="%TargetDir%\imagex.exe"
If Exist "%~dp0imagex.exe" Set Tool="%~dp0imagex.exe"
If Defined TOOL (
	::use a single WIM for all backups
	%Tool% /%method% /COMPRESS maximum %SourceDir% "%TargetDir%\%BackupName%.wim" "%BackupName% backup %YYYY%-%MM%-%DD%" "%BackupName% backup %YYYY%-%MM%-%DD% %HH%:%NN%" /CONFIG "%ExcFile%"
) else (
	DISM.exe /%method%-Image /COMPRESS:max /CaptureDir:%SourceDir% /ImageFile:"%TargetDir%\%BackupName%.wim" /Name:"%BackupName%_%YYYY%-%MM%-%DD%" /Description:"%BackupName% backup %YYYY%-%MM%-%DD% %HH%:%NN%" /ConfigFile:"%ExcFile%"
)

::create 1 WIM per month
::if exist "%TargetDir%\%BackupName%-%yyyy%-%mm%.wim" set method=APPEND
::"%TargetDir%imagex.exe" /%method% %SourceDir% "%TargetDir%\%BackupName%-%yyyy%-%mm%.wim" "%BackupName% backup %YYYY%-%MM%-%DD%" "%BackupName% backup %YYYY%-%MM%-%DD% %HH%%:%MM%" /CONFIG %ExcFile%

Call:MakeCopy %BackupName%*.wim
goto:eof

:MakeCopy
::copy to an alternate location
if defined BackupDir (
  if exist %BackupDir%\. (
	echo copy to an alternate location
 	start xcopy "%TargetDir%%1" "%BackupDir%" /C /V /Y /D
	)
)
goto:eof

:EOF