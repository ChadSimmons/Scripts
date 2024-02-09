@Echo Off
setlocal
set myCustomVariable=myCustomValue
REM ####################################################################################################################
If /I "%1"=="/h" goto:about
If /I "%1"=="/help" goto:about
goto:Initialize
:about
echo ###################################################################################################################
echo .Synopsis
echo     ScriptFileName.cmd
echo     A brief description of the function or script
echo .Description
echo     A detailed description of the function or script
echo .Parameter <Parameter-Name>
echo     The description of a parameter
echo .Example
echo     ScriptFileName.cmd -Parameter1
echo     A sample command that uses the function or script, optionally followed by sample output and a description
echo .Link
echo     The name and/or URL of a related topic
echo .NOTES
echo     This script is maintained at ??????????????????????????????????????????????????????????????????????????????????
echo     Additional information about the function or script.
echo     ========== Keywords =========================
echo     Keywords: ???
echo     ========== Change Log History ===============
echo     - YYYY/MM/DD by name@contoso.com - ~updated description~
echo     - YYYY/MM/DD by name@contoso.com - created
echo     ========== To Do / Proposed Changes =========
echo     - #TODO: None
echo     ===== Additional References and Reading =====
echo     - <link title>: https://domain.url
echo ###################################################################################################################
goto:eof
:Initialize
setlocal
set ScriptPath=%~dp0
set ScriptPath=%ScriptPath:~,-1%
set LogFile=%ProgramData%\Logs\%~n0.Log
If NOT EXIST %LogFile% (MkDir %ProgramData%\Logs & ECHO Timestamp,Status,Message > %LogFile%)
goto:main

:LogMessage
:: .Synopsis - Write timestamped message to a file or the console
:: .Parameter1 - [mandatory] Message to be logged (must be double-quoted if it contains spaces)
:: .Parameter2 - [optional] Status (Info, Warn, Error)
If [%1]==[] goto:eof
If [%LogFile%]==[] ECHO [%DATE:~10,4%-%date:~4,2%-%date:~7,2% %TIME:~0,8%] %2	%1
If NOT [%LogFile%]==[] ECHO %DATE:~10,4%-%date:~4,2%-%date:~7,2% %TIME:~0,8%,%2,%1 >> "%LogFile%"
goto:eof

:main
Call:LogMessage "========== Starting script %~0" "INFO"



ping 127.0.0.1 -n 1



:end
Call:LogMessage "========== Completed script %~0" "INFO"
If NOT [%LogFile%]==[] echo Activity logged to %LogFile%

:eof