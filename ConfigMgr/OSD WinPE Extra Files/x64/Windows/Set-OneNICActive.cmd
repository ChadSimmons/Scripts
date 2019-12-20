@Echo Off
If /I "%1"=="/?" Goto:about
If /I "%1"=="/h" Goto:about
If /I "%1"=="/help" Goto:about
Goto:Main
:about
echo ===========================================================================================
echo .Synopsis
echo     Disable all but 1 NIC and configure static IP settings
echo .Description
echo     list all NICs, disable all NICs, enable 1 NIC, use netsh to set statis IP and DNS, use reg.exe to set DNSsuffixes
echo .ChangeLog
echo    2014/07/31 by Chad.Simmons@CatapultSystems.com - Created
echo .Link
echo     http://answers.microsoft.com/en-us/windows/forum/windows_7-hardware/enabledisable-network-interface-via-command-line/17a21634-c5dd-4038-bc0a-d739209f5081
echo 	 http://slecluyse.wordpress.com/2010/08/18/enable-or-disable%C2%A0nics
echo	 http://www.petri.com/configure_tcp_ip_from_cmd.htm
echo 	 http://support.microsoft.com/kb/275553
echo	 Netsh commands for Interface IP http://technet.microsoft.com/en-us/library/bb490943.aspx
echo ===========================================================================================

:main
setlocal

::list all nics
WMIC NIC get Name, Index, NetConnectionID

echo enter the NetConnectionID of the NIC which should be enabled
set /p ActiveNIC=

Echo Disabling all NICs
wmic path win32_networkadapter where "NetConnectionID like '%%'" call disable
Echo Enable 1 NIC
wmic path win32_networkadapter where "NetConnectionID = '%ActiveNIC%'" call enable

echo Press CTRL+C to abort or
echo Enter the desired STATIC IP
set /p StaticIP=
echo Enter the desired STATIC Default Gateway
set /p Gateway=
echo Enter the desired STATIC Subnet Mask
set /p Mask=
echo Enter the desired STATIC DNS Server IP
set /p DNSIP=
echo Enter the desired STATIC Primary DNS suffix
set /p DNSsuffix=
echo Enter the desired STATIC Additional DNS suffixes (comma seperated)
set /p DNSsuffix2=

netsh interface IP set address name="%ActiveNIC%" source=static  addr=%StaticIP%  mask=%Mask%  gateway=%Gateway%
netsh interface IP set dns name="%ActiveNIC%" source=static addr=%DNSIP%
reg.exe add HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters /v "NV Domain" /d "%DNSsuffix%" /f
reg.exe add HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters /v "SearchList" /d "%DNSsuffix%,%DNSsuffix2%" /f

ipconfig /all