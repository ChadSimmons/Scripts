@ECHO OFF
SETLOCAL
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
::This batch file gathers all known local log files and specific inventories
::    then archives and copies to a server share
:: 2015/08/25 by Chad.Simmons@CatapultSystems.com - added FQDN and copy-to-server validation
:: 2012/06/10 by Chad.Simmons@CatapultSystems.com - created
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

Set _ServerLogDir=\\Server\DFSdata\ContentSource\OSD\BuildLogs\Manual\Client
Set _ServerLogDirFQDN=\\Server.contoso.com\DFSdata\ContentSource\OSD\BuildLogs\Manual\Client

::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
::echo getting the current date
for /F "tokens=2-4 delims=/ " %%i in ('date /t') do set yyyymmdd=%%k%%i%%j
::echo getting the current time
for /F "tokens=1-2 delims=: " %%l in ('time /t') do set hhmm=%%l%%m

Set _ArchiveType=ZIP

Set MyComputerName=%ComputerName%
If NOT [%1]==[] Set MyComputerName=%1
Set _ArchiveFile=%MyComputerName%_%yyyymmdd%_%hhmm%.%_ArchiveType%

:CreateLogFolders
Set _LocalLogDir=%Temp%\CopyLogs
Set _ToolsDir=%_LocalLogDir%\Tools
Set _InfoLogDir=%_LocalLogDir%\_SystemInfo
::delete existing CopyLogs folder if it exists
RMDIR /s /q "%_LocalLogDir%"
::create CopyLogs folder
MD "%_LocalLogDir%"
MD "%_InfoLogDir%"
set _statuslog="%_LocalLogDir%\status.log"

::copy 7za.exe locally if it does not exist
xcopy.exe /C /I /Y "%~dp07za.exe" "%Temp%" /D /Y

::copy tools locally and extract them
MD "%_ToolsDir%"
xcopy.exe /C /I /Y "%~dp0Tools.7z" "%_ToolsDir%" /I /D /Y
"%temp%\7za.exe" e "%_ToolsDir%\Tools.7z" -o"%_ToolsDir%"
REM "%temp%\7za.exe" e "%~dp0Tools.7z" -o"%_ToolsDir%"

::RoboCopy settings
Call:UpdateStatus "Robocopy settings..."
REM Set _rcopyOpt=/COPY:DT /R:0 /NP /XJD /XJF /TEE /LOG+:"%_LocalLogDir%\robocopy.log"
REM    remove /TEE since MDT/OSD captues the screen output and fills up SMSTS.log
Set _rcopyOpt=/COPY:DT /R:0 /NP /XJD /XJF /LOG+:"%_LocalLogDir%\robocopy.log"
set _XF=/XF *.log1 *.log2 MSDTC.log edb.log
set _XD=/XD CopyLogs WinSXS _delete "Windows Mail" "System Volume Information"
::assume robocopy.exe exists and is in the PATH
Set _rcopy="robocopy.exe"
GOTO:GatherLogs

:GatherLogs
::Gather logs from various locations
Call:UpdateStatus "Gathering logs..."
REM (done below) %_rcopy% D:\ "%_LocalLogDir%\DriveD" *.log /S %_XD% %_XF% %_rcopyOpt%
REM (not needed) %_rcopy% X:\ "%_LocalLogDir%\DriveX" *.log /S %_XD% %_XF% %_rcopyOpt%

REM ::generally found in WinPE / MDT / OSD scenarios
set _drive=C
%_rcopy% %_Drive%:\ "%_LocalLogDir%\Drive%_Drive%" *.log /S %_XD% %_XF% %_rcopyOpt%
%_rcopy% "%_Drive%:\SMSTSLog" "%_LocalLogDir%\Drive%_Drive%\SMSTSLog" /S %_rcopyOpt%
%_rcopy% "%_Drive%:\_SMSTaskSequence\Logs" "%_LocalLogDir%\Drive%_Drive%\_SMSTaskSequence\Logs" /S %_rcopyOpt%
%_rcopy% "%_Drive%:\Windows\Temp" "%_LocalLogDir%\Drive%_Drive%\Windows\Temp" kb*.* /S %_XD% %_XF% %_rcopyOpt%
%_rcopy% "%_Drive%:\Windows\Panther" "%_LocalLogDir%\Drive%_Drive%\Windows\Panther" /S %_XD% %_XF% %_rcopyOpt%
%_rcopy% "%_Drive%:\Windows\system32\Panther" "%_LocalLogDir%\Drive%_Drive%\Windows\system32\Panther" /S %_XD% %_XF% %_rcopyOpt%
%_rcopy% "%_Drive%:\Windows\system32\sysprep\Panther" "%_LocalLogDir%\Drive%_Drive%\Windows\system32\sysprep\Panther" /S %_XD% %_XF% %_rcopyOpt%

set _drive=D
%_rcopy% %_Drive%:\ "%_LocalLogDir%\Drive%_Drive%" *.log /S %_XD% %_XF% %_rcopyOpt%
%_rcopy% "%_Drive%:\SMSTSLog" "%_LocalLogDir%\Drive%_Drive%\SMSTSLog" /S %_rcopyOpt%
%_rcopy% "%_Drive%:\_SMSTaskSequence\Logs" "%_LocalLogDir%\Drive%_Drive%\_SMSTaskSequence\Logs" /S %_rcopyOpt%
%_rcopy% "%_Drive%:\Windows\Temp" "%_LocalLogDir%\Drive%_Drive%\Windows\Temp" kb*.* /S %_XD% %_XF% %_rcopyOpt%
%_rcopy% "%_Drive%:\Windows\Panther" "%_LocalLogDir%\Drive%_Drive%\Windows\Panther" /S %_XD% %_XF% %_rcopyOpt%
%_rcopy% "%_Drive%:\Windows\system32\Panther" "%_LocalLogDir%\Drive%_Drive%\Windows\system32\Panther" /S %_XD% %_XF% %_rcopyOpt%
%_rcopy% "%_Drive%:\Windows\system32\sysprep\Panther" "%_LocalLogDir%\Drive%_Drive%\Windows\system32\sysprep\Panther" /S %_XD% %_XF% %_rcopyOpt%

set _drive=E
%_rcopy% %_Drive%:\ "%_LocalLogDir%\Drive%_Drive%" *.log /S %_XD% %_XF% %_rcopyOpt%
%_rcopy% "%_Drive%:\SMSTSLog" "%_LocalLogDir%\Drive%_Drive%\SMSTSLog" /S %_rcopyOpt%
%_rcopy% "%_Drive%:\_SMSTaskSequence\Logs" "%_LocalLogDir%\Drive%_Drive%\_SMSTaskSequence\Logs" /S %_rcopyOpt%
%_rcopy% "%_Drive%:\Windows\Temp" "%_LocalLogDir%\Drive%_Drive%\Windows\Temp" kb*.* /S %_XD% %_XF% %_rcopyOpt%
%_rcopy% "%_Drive%:\Windows\Panther" "%_LocalLogDir%\Drive%_Drive%\Windows\Panther" /S %_XD% %_XF% %_rcopyOpt%
%_rcopy% "%_Drive%:\Windows\system32\Panther" "%_LocalLogDir%\Drive%_Drive%\Windows\system32\Panther" /S %_XD% %_XF% %_rcopyOpt%
%_rcopy% "%_Drive%:\Windows\system32\sysprep\Panther" "%_LocalLogDir%\Drive%_Drive%\Windows\system32\sysprep\Panther" /S %_XD% %_XF% %_rcopyOpt%

set _drive=X
%_rcopy% "%_drive%:\SMSTSLog" "%_LocalLogDir%\Drive%_drive%\SMSTSLog" /S %_rcopyOpt%
%_rcopy% "%_drive%:\Windows\Temp" "%_LocalLogDir%\Drive%_drive%\Windows\Temp" *.log kb*.* /S /XD CopyLogs %_rcopyOpt%

::Export network settings
Call:UpdateStatus "Exporting network settings..."
ipconfig /all > "%_InfoLogDir%\IPConfig.txt"
arp -a -v > "%_InfoLogDir%\ARP.txt"
::gpresult /H "%_InfoLogDir%\GPResult.html"
::gpresult /Z > "%_InfoLogDir%\GPResult.txt"

::Export Environment Variables
set > "%_InfoLogDir%\Set.txt"

::Export OSD Task Sequence Variables
cscript.exe /nologo OutputTSVariables.vbs > "%_InfoLogDir%\OSDTSVars_vbs.txt"
cscript.exe /nologo OutputTSVariables.wsf > "%_InfoLogDir%\OSDTSVars_wsf.txt"
PowerShell.exe -ExecutionPolicy Bypass -file .\OutputTSVariables.ps1 > "%_InfoLogDir%\OSDTSVars_ps1.txt"

Call:UpdateStatus "Exporting local admins..."
net localgroup administrators >  "%_InfoLogDir%\Local Administrators.txt"
Call:UpdateStatus "Exporting current users info..."
net user %username% /domain > "%_InfoLogDir%\NetUser_%UserName%.txt"
Call:UpdateStatus "Exporting SystemInfo..."
systeminfo /FO LIST > "%_InfoLogDir%\SystemInfo.txt"

::???????????????????????????????????????????????

:DeleteTools
Call:UpdateStatus "Deleting tools..."
RMDIR /s /q "%_ToolsDir%"

:CompressLogs
::Compress logs before sending to the Server
Call:UpdateStatus "Compressing data..."
"%Temp%\7za.exe" a -mx9 -t%_ArchiveType% -r "%temp%\%_ArchiveFile%" "%_LocalLogDir%\*.*"

:CopyToServer
::Copy the log archive file to the server
Call:UpdateStatus "Uploading data to server..."
xcopy.exe /C /I /Y "%temp%\%_ArchiveFile%" "%_ServerLogDirFQDN%"
if exist "%_ServerLogDirFQDN%\%_ArchiveFile%" goto:LogIsOnServer
::If the copying using the FQDN failed try without it
xcopy.exe /C /I /Y "%temp%\%_ArchiveFile%" "%_ServerLogDir%"
if exist "%_ServerLogDir%\%_ArchiveFile%" goto:LogIsOnServer
::If the archive file was still not copied to the server display error
echo !!!!! ERROR !!!!! %_ArchiveFile% is NOT on %_ServerLogDirFQDN%
echo       try running the command manually
echo       xcopy.exe /C /I /Y "%temp%\%_ArchiveFile%" "%_ServerLogDirFQDN%"
goto:Cleanup

:LogIsOnServer
echo Archive copied to server

:Cleanup
if exist "%_LocalLogDir%\." RMDIR /s /q "%_LocalLogDir%"
if exist "%Temp%\7za.exe" del "%Temp%\7za.exe"
Echo.
Echo.
Echo.
echo NOT Deleting Local Log File Archive at
echo     "%temp%\%_ArchiveFile%"
Echo Server Log File Archive is at
echo     %_ServerLogDir%\%_ArchiveFile%
goto:eof

:UpdateStatus
::"%_ToolsDir%\nircmd.exe" execmd echo $currdate.yyyyMMdd$,$currtime.HHmmss$,%1 >> %_statuslog%
goto:eof

:EOF
