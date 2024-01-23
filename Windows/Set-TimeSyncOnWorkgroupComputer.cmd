@echo off
::https://learn.microsoft.com/en-us/windows-server/networking/windows-time-service/windows-time-service-tools-and-settings?tabs=config#command-line-parameters-for-w32time
setlocal
set timePeers=pool.ntp.org lab-dc1.lab.local
w32tm /config /update /manualpeerlist:%timePeers% /syncfromflags:ALL
sc config W32time start=delayed-auto
sc stop W32time
sc start W32time