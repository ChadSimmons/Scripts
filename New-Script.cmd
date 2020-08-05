@Echo Off
setlocal
set myCustomVariable=myCustomValue
::=================================================================================================
If /I "%1"=="/?" goto:about
If /I "%1"=="/h" goto:about
If /I "%1"=="/help" goto:about
goto:main
:about
echo ===========================================================================================
echo .Synopsis
echo     A brief description of the function or script.
echo .Description
echo     A detailed description of the function or script.
echo .Parameter  <Parameter-Name>
echo     The description of a parameter. Add a .PARAMETER keyword For each parameter IN the function or script syntax.
echo .Example
echo     A sample command that uses the function or script, optionally followed by sample output and a description. Repeat this keyword For each example.
echo .Inputs
echo     A description of the inputs.
echo .Outputs
echo     A description of the output.
echo .Notes
echo    Additional information about the function or script.
echo    ========== Keywords ==========
echo    Keywords:
echo    ========== Change Log History ==========
echo    - yyyy/mm/dd by Chad Simmons - Modified $ChangeDescription$
echo    - 2017/12/27 by Chad.Simmons@CatapultSystems.com - Created
echo    - 2017/12/27 by Chad@ChadsTech.net - Created
echo    === To Do / Proposed Changes ===
echo    - TODO: ???
echo .Link
echo     The name and/or URL of a related topic.
echo ===========================================================================================
goto:eof
:main

:eof