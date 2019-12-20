@echo off
echo !!!!! WARNING !!!!! This will erase your hard drive !!!!! WARNING !!!!!
echo Press CTRL+C to abort or
pause
echo select disk 0 > x:\Clean-Disk0.txt
echo clean >> x:\Clean-Disk0.txt
if exist x:\Clean-Disk0.txt diskpart /s x:\Clean-Disk0.txt