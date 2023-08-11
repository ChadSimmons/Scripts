# Update-MicrosoftStoreApps.ps1
# Attempt to force  Microsoft Store applications to update
#	A user must be logged in 
#	The computer must have Internet access unrestricted to Microsoft Store URLs / IPs

# Get inventory of Microsoft Store apps from ConfigMgr WMI class
Get-WmiObject -Query 'SELECT * FROM SMS_Windows8Application' -Namespace 'root\cimv2\sms' -ErrorAction SilentlyContinue

# Set policy to allow Windows Update Agent to Internet content delivery network, not just an internal/WSUS source
Set-ItemProperty -Path 'HKLM:\Software\Policies\Microsoft\Windows\WindowsUpdate' -Name 'DoNotConnectToWindowsUpdateInternetLocations' -Value 0 -Type DWORD -Force #Disable / Allow

# Trigger Microsoft Store app updates scan
$WmiObj = Get-WmiObject -Namespace 'root\CIMv2\mdm\dmmap' -Class 'MDM_EnterpriseModernAppManagement_AppManagement01'
$result = $WmiObj.UpdateScanMethod()

# exit with return code
exit $result.ReturnValue
