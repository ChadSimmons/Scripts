# Cancel-MCMPendingReboot.ps1
# Cancel a ConfigMgr pending reboot
# https://sccmf12twice.com/sccm-reboot-decoded-how-to-make-a-pc-cancel-start-extend-or-change-mandatory-reboot-to-non-mandatory-on-the-fly
Remove-Item -path 'HKLM:\SOFTWARE\Microsoft\SMS\Mobile Client\Reboot Management\RebootData';
Remove-Item -path 'HKLM:\SOFTWARE\Microsoft\SMS\Mobile Client\Updates Management\Handler\UpdatesRebootStatus\*';
Remove-ItemProperty -name * -path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired';
#on PS2.0, "Remove-ItemProperty" doesn't work, so use this. #Remove-Item -path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired';
Shutdown.exe -a
Restart-Service -Force -Name CCMEXEC, WUAUSERV
