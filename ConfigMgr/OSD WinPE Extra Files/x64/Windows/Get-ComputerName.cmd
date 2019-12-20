@Echo off
:: Ping %1
:: Get IP from Ping
:: Get ComputerName from registry of IP
:: Get ComputerName from ping -a
:: Get ComputerName from NBTStat -a IP

Ping -a %1
pause
reg query \\%1\HKLM\System\CurrentControlSet\Control\ComputerName\ActiveComputerName /v ComputerName
nbtstat -a %1