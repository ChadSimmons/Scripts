@echo off
::.Example
::   "E:\Program Files\ConfigMgr Tools\Write-StatusMessageLog.cmd" %msgltm/%msgltd/%msgltY %msgltH:%msgltM:%msgltS %msgid "%msgsys" "%msgdesc" "%msgis01" "%msgis02"
::   cmd.exe /c echo %msgltm/%msgltd/%msgltY %msgltH:%msgltM:%msgltS,%msgid,%msgsys,%msgdesc,%msgis01 >> E:\Logs\Custom\ConfigMgr_StatusMessages.csv
::   cmd.exe /c echo %msgltm %msgltd %msgltY %msgltH %msgltM %msgltS,%msgid,%msgsys >> E:\Logs\Custom\ConfigMgr_StatusMessages.csv

::.Notes
::   ConfigMgr: Command-Line Parameters for Status Filter Rules
::   https://technet.microsoft.com/en-us/library/bb693758.aspx
::   
::   %msgsys	Name of the computer that reported the message 
::   %msgdesc Complete message description text 
::   %msgis01 First "insertion string" 
::   ...
::   %msgis10 Tenth "insertion string" 
::   %msgltm	Time the message was reported, converted to local time: Month as decimal number (01 – 12)
::   %msgltd	Time the message was reported, converted to local time: Day of month as decimal number (01 – 31)
::   %msgltY	Time the message was reported, converted to local time: Year with century, as decimal number 
::   %msgltH	Time the message was reported, converted to local time: Hour in 24-hour format (00 – 23)
::   %msgltM	Time the message was reported, converted to local time: Minute as decimal number (00 – 59)
::   %msgltS	Time the message was reported, converted to local time: Second as decimal number (00 – 59)
::   %msgid	Message ID of the message 
::   %msgltm/%msgltd/%msgltY %msgltH:%msgltM:%msgltS,%msgid,%msgsys,%msgdesc,%msgis01

set filename="D:\Logs\Custom\ConfigMgr_StatusMessages.csv"

If NOT EXIST %filename% echo ComputerName;Timestamp;MessageType;Status;MessageDetails1;MessageDetails2;MessageDetails3;MessageDetails4;MessageDetails5 > %filename%
echo %1;%2;%3;%4;%5;%6;%7;%8;%9 >> %filename%
