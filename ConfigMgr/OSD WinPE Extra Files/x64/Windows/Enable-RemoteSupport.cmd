@echo off
setlocal
If /I "[%1]"=="/h" Goto:about
If /I "[%1]"=="/help" Goto:about
goto:Begin
:about
echo ===========================================================================================
echo .Synopsis
echo    Enable Remote Support
echo .Description
echo    Add exceptions to the Windows Firewall for ICMP v4 (Ping)
echo    Add exceptions to the Windows Firewall for Remote Administration (WinRM, RDP, File and Printer Sharing)
echo    Add exceptions to the Windows Firewall for VNC
echo    Configure WinRM
echo    Disable the Windows Firewall
echo.
echo    Not all commands work in WinPE or Windows.  Some errors are expected.
echo .Parameters
echo   [/h] [/help] display this help information
echo .Notes
echo    === Change Log History ===
echo    2015/08/27 by Chad.Simmons@CatapultSystems.com - Created
echo ===========================================================================================
goto:eof

:Begin
echo Enable ICMP (ping)
netsh advfirewall firewall set rule name="File and Printer Sharing (Echo Request - ICMPv4-In)" new enable=Yes

echo Enable RDP
netsh advfirewall firewall set rule group="Remote Desktop" new enable=Yes

echo Enable Remote Administrator
netsh advfirewall firewall set rule group="remote administration" new enable=yes

echo Enable VNC
netsh advfirewall firewall add rule name="VNC (TCP-in)" dir=in action=allow protocol=TCP localport=5900

echo Disable Windows Firewall
netsh advfirewall set allprofiles state off
wpeutil DisableFirewall

echo Enable WinRM for Remote access
winrm quickconfig