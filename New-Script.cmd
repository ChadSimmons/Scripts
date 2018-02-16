@Echo Off
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
echo .ChangeLog
echo    Additional information about the function or script.
echo    - [yyyy/mm/dd] by [my.name@email.com] - Modified [ChangeDescription]
echo    - [yyyy/mm/dd] by [my.name@email.com] - Created
echo .Link
echo     The name and/or URL of a related topic.
echo .Functionality
echo     The intended use of the function.
echo ===========================================================================================
goto:eof
:main

:eof