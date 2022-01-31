@ECHO OFF
SETLOCAL
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
::This batch file gathers all known local log files and specific inventories
::    then archives and copies to a server share
:: 2015/08/25 by Chad.Simmons@CatapultSystems.com - added FQDN and copy-to-server validation
:: 2012/06/10 by Chad.Simmons@CatapultSystems.com - created
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

Set _ServerLogDir=\\server\logs$\OSD
Set _ServerLogDirFQDN=\\server.domain.com\logs$\OSD

::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
::echo getting the current date
for /F "tokens=2-4 delims=/ " %%i in ('date /t') do set yyyymmdd=%%k%%i%%j
::echo getting the current time
for /F "tokens=1-2 delims=: " %%l in ('time /t') do set hhmm=%%l%%m

Set _ArchiveType=ZIP
Set _ArchiveFile=%ComputerName%_%yyyymmdd%_%hhmm%.%_ArchiveType%

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
xcopy "%~dp07za.exe" "%Temp%" /D /Y

::copy tools locally and extract them
MD "%_ToolsDir%"
xcopy "%~dp0Tools.7z" "%_ToolsDir%" /I /D /Y
"%temp%\7za.exe" e "%_ToolsDir%\Tools.7z" -o"%_ToolsDir%"
REM "%temp%\7za.exe" e "%~dp0Tools.7z" -o"%_ToolsDir%"

::RoboCopy settings
Call:UpdateStatus "Robocopy settings..."
REM Set _rcopyOpt=/COPY:DT /R:0 /NP /XJD /XJF /TEE /LOG+:"%_LocalLogDir%\robocopy.log"
REM    remove /TEE since MDT/OSD captues the screen output and fills up SMSTS.log
Set _rcopyOpt=/R:0 /W:0 /COPY:DTX /A+:A /DCOPY:DTX /NP /XJD /XJF /LOG+:"%_LocalLogDir%\robocopy.log"
set _XF=/XF *.log1 *.log2 MSDTC.log edb.log
set _XD=/XD CopyLogs WinSXS _delete "Windows Mail" "System Volume Information"
::If robocopy does not exist locally, copy it
Set _rcopy="%WinDir%\System32\robocopy.exe"
IF Exist "%WinDir%\System32\robocopy.exe" GOTO:GatherLogs
IF Exist "%_LocalLogDir%\robocopy.exe" GOTO:GatherLogs
::if robocopy.exe does not exist, copy it locally and set the new rcopy path
REM "%temp%\7za.exe" e "%~dp0robocopy.7z" -o"%_ToolsDir%"
Set _rcopy="%_ToolsDir%\robocopy.exe"


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
IPConfig.exe /all > "%_InfoLogDir%\IPConfig.txt"
arp -a -v > "%_InfoLogDir%\ARP.txt"
GPResult.exe /scope:Computer /H "%_InfoLogDir%\GPResult.html"
GPResult.exe /scope:Computer /Z > "%_InfoLogDir%\GPResult.txt"

:Export_WMI_Inventory
WMIC.exe /OUTPUT:"%_InfoLogDir%\WMI_BASEBOARD.txt" BASEBOARD GET * /FORMAT:LIST
WMIC.exe /OUTPUT:"%_InfoLogDir%\WMI_BIOS.txt" BIOS GET * /FORMAT:LIST
WMIC.exe /OUTPUT:"%_InfoLogDir%\WMI_BOOTCONFIG.txt" BOOTCONFIG GET * /FORMAT:LIST
WMIC.exe /OUTPUT:"%_InfoLogDir%\WMI_COMPUTERSYSTEM.txt" COMPUTERSYSTEM GET * /FORMAT:LIST
WMIC.exe /OUTPUT:"%_InfoLogDir%\WMI_CPU.txt" CPU GET * /FORMAT:LIST
WMIC.exe /OUTPUT:"%_InfoLogDir%\WMI_CSPRODUCT.txt" CSPRODUCT GET * /FORMAT:LIST
WMIC.exe /OUTPUT:"%_InfoLogDir%\WMI_DISKDRIVE.txt" DISKDRIVE GET * /FORMAT:LIST
WMIC.exe /OUTPUT:"%_InfoLogDir%\WMI_ENVIRONMENT.txt" ENVIRONMENT GET * /FORMAT:LIST
WMIC.exe /OUTPUT:"%_InfoLogDir%\WMI_LOGICALDISK.txt" LOGICALDISK GET * /FORMAT:LIST
WMIC.exe /OUTPUT:"%_InfoLogDir%\WMI_NIC.txt" NIC GET * /FORMAT:LIST
WMIC.exe /OUTPUT:"%_InfoLogDir%\WMI_NICCONFIG.txt" NICCONFIG GET * /FORMAT:LIST
WMIC.exe /OUTPUT:"%_InfoLogDir%\WMI_OS.txt" OS GET * /FORMAT:LIST
WMIC.exe /OUTPUT:"%_InfoLogDir%\WMI_PARTITION.txt" PARTITION GET * /FORMAT:LIST
WMIC.exe /OUTPUT:"%_InfoLogDir%\WMI_QFE.txt" QFE GET * /FORMAT:LIST
WMIC.exe /OUTPUT:"%_InfoLogDir%\WMI_SYSDRIVER.txt" SYSDRIVER GET * /FORMAT:LIST
WMIC.exe /OUTPUT:"%_InfoLogDir%\WMI_SYSTEMENCLOSURE.txt" SYSTEMENCLOSURE GET * /FORMAT:LIST

WMIC.exe /OUTPUT:"%_InfoLogDir%\WMI_BASEBOARD.html" BASEBOARD GET * /FORMAT:HFORM
WMIC.exe /OUTPUT:"%_InfoLogDir%\WMI_BIOS.html" BIOS GET * /FORMAT:HFORM
WMIC.exe /OUTPUT:"%_InfoLogDir%\WMI_BOOTCONFIG.html" BOOTCONFIG GET * /FORMAT:HFORM
WMIC.exe /OUTPUT:"%_InfoLogDir%\WMI_COMPUTERSYSTEM.html" COMPUTERSYSTEM GET * /FORMAT:HFORM
WMIC.exe /OUTPUT:"%_InfoLogDir%\WMI_CPU.html" CPU GET * /FORMAT:HFORM
WMIC.exe /OUTPUT:"%_InfoLogDir%\WMI_CSPRODUCT.html" CSPRODUCT GET * /FORMAT:HFORM
WMIC.exe /OUTPUT:"%_InfoLogDir%\WMI_DISKDRIVE.html" DISKDRIVE GET * /FORMAT:HFORM
WMIC.exe /OUTPUT:"%_InfoLogDir%\WMI_ENVIRONMENT.html" ENVIRONMENT GET * /FORMAT:HFORM
WMIC.exe /OUTPUT:"%_InfoLogDir%\WMI_LOGICALDISK.html" LOGICALDISK GET * /FORMAT:HFORM
WMIC.exe /OUTPUT:"%_InfoLogDir%\WMI_NIC.html" NIC GET * /FORMAT:HFORM
WMIC.exe /OUTPUT:"%_InfoLogDir%\WMI_NICCONFIG.html" NICCONFIG GET * /FORMAT:HFORM
WMIC.exe /OUTPUT:"%_InfoLogDir%\WMI_OS.html" OS GET * /FORMAT:HFORM
WMIC.exe /OUTPUT:"%_InfoLogDir%\WMI_PARTITION.html" PARTITION GET * /FORMAT:HFORM
WMIC.exe /OUTPUT:"%_InfoLogDir%\WMI_QFE.html" QFE GET * /FORMAT:HFORM
WMIC.exe /OUTPUT:"%_InfoLogDir%\WMI_SYSDRIVER.html" SYSDRIVER GET * /FORMAT:HFORM
WMIC.exe /OUTPUT:"%_InfoLogDir%\WMI_SYSTEMENCLOSURE.html" SYSTEMENCLOSURE GET * /FORMAT:HFORM

::Export Environment Variables
set > "%_InfoLogDir%\EnvironmentVariables.txt"

::Export OSD Task Sequence Variables
If EXIST OutputTSVariables.vbs cscript.exe /nologo OutputTSVariables.vbs > "%_InfoLogDir%\OSDTSVars_vbs.txt"
If EXIST OutputTSVariables.wsf cscript.exe /nologo OutputTSVariables.wsf > "%_InfoLogDir%\OSDTSVars_wsf.txt"
If EXIST OutputTSVariables.ps1 PowerShell.exe -ExecutionPolicy Bypass -file .\OutputTSVariables.ps1 > "%_InfoLogDir%\OSDTSVars_ps1.txt"

Call:UpdateStatus "Exporting local admins..."
net localgroup administrators >  "%_InfoLogDir%\Local Administrators.txt"
Call:UpdateStatus "Exporting current users info..."
net user %username% /domain > "%_InfoLogDir%\NetUser_%UserName%.txt"
Call:UpdateStatus "Exporting SystemInfo..."
SystemInfo.exe /FO LIST > "%_InfoLogDir%\SystemInfo.txt"

::???????????????????????????????????????????????

:DeleteTools
Call:UpdateStatus "Deleting tools..."
RMDIR /s /q "%_ToolsDir%"

:CompressLogs
::Compress logs before sending to the Server
Call:UpdateStatus "Compressing data..."
::Remove System, Read Only, and Hiddent Attributes from all copied files and folders
attrib.exe /D /S -R -S -H +A "%_LocalLogDir%"
attrib.exe /D /S -R -S -H +A "%_LocalLogDir%\DriveC"
"%Temp%\7za.exe" a -mx9 -t%_ArchiveType% -r "%temp%\%_ArchiveFile%" "%_LocalLogDir%\*.*"

:CopyToServer
::Copy the log archive file to the server
Call:UpdateStatus "Uploading data to server..."
xcopy "%temp%\%_ArchiveFile%" "%_ServerLogDirFQDN%"
if exist "%_ServerLogDirFQDN%\%_ArchiveFile%" goto:LogIsOnServer
::If the copying using the FQDN failed try without it
xcopy "%temp%\%_ArchiveFile%" "%_ServerLogDir%"
if exist "%_ServerLogDir%\%_ArchiveFile%" goto:LogIsOnServer
::If the archive file was still not copied to the server display error
echo !!!!! ERROR !!!!! %_ArchiveFile% is NOT on %_ServerLogDirFQDN%
echo       try running the command manually
echo       xcopy "%temp%\%_ArchiveFile%" "%_ServerLogDirFQDN%"
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
Echo %1
::"%_ToolsDir%\nircmd.exe" execmd echo $currdate.yyyyMMdd$,$currtime.HHmmss$,%1 >> %_statuslog%
goto:eof
