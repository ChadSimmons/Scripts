::Run Dell Command | Update Version 3.1.1 to update drivers
::Requires https://www.dell.com/support/article/en-us/sln311129/dell-command-update?lang=en
START /wait "Updating Dell drivers..." <EDIT THE DIRECTORY HERE>\dcu-cli.exe /applyUpdates -reboot=disable
SET ReturnCode=%errorlevel%
:: ===== Process Return Code =====
:: https://www.dell.com/support/manuals/us/en/04/command-update/dellcommandupdate_3.1.1_ug/command-line-interface-error-codes?guid=guid-f39c91a1-a1ce-4130-be73-8d6fae2ccc5f&lang=en-us
::    Decimal ERROR_NAME: Error description
::          0 ERROR_SUCCESS: Success, no reboot required
::          1 A reboot was required from the execution of an operation
::          5 A reboot was pending from a previous operation
::          7 The application does not support the current system model
:: https://docs.microsoft.com/en-us/openspecs/windows_protocols/ms-erref/18d8fbe8-a967-4f1c-ae50-99ca8e491d2d
:: https://docs.microsoft.com/en-us/windows/win32/debug/system-error-codes
::        999 One of several Fail FastRetry return codes know by ConfigMgr
::         10 ERROR_BAD_ENVIRONMENT
:: Set Default to 999 / Retry
SET FinalReturnCode=999
If %ReturnCode%==0 SET FinalReturnCode=0
If %ReturnCode%==1 SET FinalReturnCode=3010
If %ReturnCode%==3 SET FinalReturnCode=10
If %ReturnCode%==5 SET FinalReturnCode=3010
If %ReturnCode%==7 SET FinalReturnCode=10
If %ReturnCode%==500 SET FinalReturnCode=0
EXIT /b %FinalReturnCode%