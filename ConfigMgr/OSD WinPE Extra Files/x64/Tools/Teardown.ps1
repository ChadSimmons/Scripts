<#
.SYNOPSIS  
  Removes the temporary file created by SetupWinPEBoot.ps1 to fill an attached USB disk
.DESCRIPTION
	Deletes directory {Drive:}\1EWSA\_dummy_stuff in all drives  
.LINK
  http://help.1e.com/display/WSS30/Scripts+for+Microsoft+VPN+client
.NOTES
  Version:        1
  Author:         Sravan Goud  
  Creation Date:  03-05-2018
  Last Modified Date:  03-05-2018
  Purpose/Change: Initial script development
#>
$disks = Get-WMIObject -Class 'Win32_LogicalDisk' -Namespace 'root\CIMv2'
ForEach ($disk in $disks) {
    $DummyFolder = Join-Path -Path $disk.DeviceID -ChildPath '\1EWSA\_dummy_stuff'
    If (Test-Path -Path $DummyFolder) {
      Remove-Item $DummyFolder -Force -Recurse
    }
}