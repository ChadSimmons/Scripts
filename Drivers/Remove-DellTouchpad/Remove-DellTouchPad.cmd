@Echo off
Echo Removing Dell TouchPad driver (Device ID ACPI\VEN_DLL&DEV_06DB)
%~dp0devcon.exe remove "ACPI\VEN_DLL&DEV_06DB"
Echo Please restart the computer to make the change effective.