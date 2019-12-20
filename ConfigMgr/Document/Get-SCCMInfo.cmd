@echo off
setlocal
set myCompany=FHLB Dallas
set myDomain=FHLB.com
set myForest=FHLB.com
set myDCserver=PEGASUS
set myCMServer=BOURNE
set mySQLServer=BOURNE
set myUserName=ConfigMgr Admin
set mySaveDir=U:\MyDocs\ConfigMgr Documentation

If /I [%1]==[/?] goto:Help
If /I [%1]==[-?] goto:Help
If /I [%1]==[/h] goto:Help
If /I [%1]==[-h] goto:Help
If /I [%1]==[/help] goto:Help
If /I [%1]==[-help] goto:Help
goto:Begin
:Help
echo ===============================================================================
echo .Synopsis
echo    Document a Microsoft System Center Configuration Manager environment using
echo       scripts.
echo .Description
echo    Scripted Documentation
echo .Functionality
echo    Execute scripts to produce .XML, .HTML and .DOCX reports
echo .Parameters
echo    [/h] [/help]      display this help information
echo .Notes
echo    === References and Sources ===
echo    DocumentCM12R2v2.ps1 version 1.00 updated 2015/04/06 by David O'Brien, Carl Webster, Michael B. Smith, Iain Brighton, Jeff Wouters, Barry Schiffer
echo    CM12sydi-143.vbs version 1.43 updated 2013/12/24 by Garth Jones at http://www.enhansoft.com/downloads/vbs/CM12Sydi-143.zip
echo    sydi-server.vbs version 2.4 updated 2014/10/26 by http://sydiproject.com
echo    sydi-sql.vbs version 0.8 updated 2005/04/05 by http://sydiproject.com
echo    ADDS_Inventory_v1_1.ps1 version 1.11 updated 2015/07/08 by http://www.CarlWebster.com
echo    === Change Log History ===
echo    2015/09/23 by Chad.Simmons@CatapultSystems.com - Created
echo ================================================================================
goto:eof

:Begin
SET SourceDir=%~dp0
SET SourceDir=%SourceDir:~,-1%

If NOT Defined mySaveDir set mySaveDir=%SourceDir%\ConfigMgr Documentation
If NOT EXIST "%mySaveDir%" MkDir "%mySaveDir%"

:Get_ADInventory
pushd "%SourceDir%\ADDS"
PowerShell -ExecutionPolicy Bypass -File .\ADDS_Inventory_V1_1.ps1 -AddDateTime -MSWord -CompanyName "%myCompany%" -UserName "%myUserName%" -Hardware -ADForest %myForest% -ComputerName %myDCserver%
popd

:Get_SQLInventory
pushd "%SourceDir%\SYDI"
set myServer=%mySQLServer%
set myServerFQDN=%myServer%.%myDomain%
cscript.exe sydi-server.vbs -wafgsu -rc -f11 -ex -d -t%myServerFQDN% -o"%mySaveDir%\%myServer%.xml"
cscript.exe sydi-server.vbs -wafgsu -rc -f11 -ex -sh -d -t%myServerFQDN% -o"%mySaveDir%\%myServer%.html"
cscript.exe sydi-server.vbs -wafgsu -rc -f11 -ew -d -t%myServerFQDN% -o"%mySaveDir%\%myServer%.docx"
cscript.exe sydi-sql.vbs -S -l1 -ex -s -t%myServerFQDN% -o"%mySaveDir%\%myServer%_SQL.xml"
cscript.exe sydi-sql.vbs -S -l1 -ex -sh -t%myServerFQDN% -o"%mySaveDir%\%myServer%_SQL.html"
cscript.exe sydi-sql.vbs -S -l1 -ew -sh -d -t%myServerFQDN% -o"%mySaveDir%\%myServer%_SQL.docx"
popd

:Get_ConfigMgrInventory
set myServer=%myCMServer%
set myServerFQDN=%myServer%.%myDomain%
pushd "%SourceDir%\SYDI"
cscript.exe sydi-server.vbs -wafgsu -rc -f11 -ex -s -t%myServerFQDN% -o"%mySaveDir%\%myServer%.xml"
cscript.exe sydi-server.vbs -wafgsu -rc -f11 -ex -sh -t%myServerFQDN% -o"%mySaveDir%\%myServer%.html"
cscript.exe sydi-server.vbs -wafgsu -rc -f11 -ew -d -t%myServerFQDN% -o"%mySaveDir%\%myServer%.docx"
cscript.exe CM12Sydi-143.vbs -wacmpqs -f11 -ew -t%myServerFQDN% -o"%mySaveDir%\%myServer%_ConfigMgr.docx"
popd
PowerShell -ExecutionPolicy Bypass -File .\DocumentCM12R2v2.ps1 -AddDateTime -MSWord -CompanyName "%myCompany%" -UserName "%myUserName%" -Software -ListAllInformation -SMSProvider %myServerFQDN%

:eof
