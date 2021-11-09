@Echo Off
setlocal
set myCustomVariable=myCustomValue
REM ####################################################################################################################
If /I "%1"=="/h" goto:about
If /I "%1"=="/help" goto:about
goto:main
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
setlocal
set ScriptPath=%~dp0
set ScriptPath=%ScriptPath:~,-1%
:main

:eof