#.Synopsis
#   Set-WindowsNetworkConnectionDefaultAsNonMetered.ps1
#   Set the default metered connection configuration as non-metered for detected 4G and 3G network connections
#
#   Take Ownership of a Windows registry key path, set desired permissions, and set a value

function Enable-Privilege {
# https://community.spiceworks.com/topic/2127465-windows-10-powershell-take-ownership-of-a-registry-key
 param(
  ## The privilege to adjust. This set is taken from
  ## http://msdn.microsoft.com/en-us/library/bb530716(VS.85).aspx
  [ValidateSet(
   "SeAssignPrimaryTokenPrivilege", "SeAuditPrivilege", "SeBackupPrivilege",
   "SeChangeNotifyPrivilege", "SeCreateGlobalPrivilege", "SeCreatePagefilePrivilege",
   "SeCreatePermanentPrivilege", "SeCreateSymbolicLinkPrivilege", "SeCreateTokenPrivilege",
   "SeDebugPrivilege", "SeEnableDelegationPrivilege", "SeImpersonatePrivilege", "SeIncreaseBasePriorityPrivilege",
   "SeIncreaseQuotaPrivilege", "SeIncreaseWorkingSetPrivilege", "SeLoadDriverPrivilege",
   "SeLockMemoryPrivilege", "SeMachineAccountPrivilege", "SeManageVolumePrivilege",
   "SeProfileSingleProcessPrivilege", "SeRelabelPrivilege", "SeRemoteShutdownPrivilege",
   "SeRestorePrivilege", "SeSecurityPrivilege", "SeShutdownPrivilege", "SeSyncAgentPrivilege",
   "SeSystemEnvironmentPrivilege", "SeSystemProfilePrivilege", "SeSystemtimePrivilege",
   "SeTakeOwnershipPrivilege", "SeTcbPrivilege", "SeTimeZonePrivilege", "SeTrustedCredManAccessPrivilege",
   "SeUndockPrivilege", "SeUnsolicitedInputPrivilege")]
  $Privilege,
  ## The process on which to adjust the privilege. Defaults to the current process.
  $ProcessId = $pid,
  ## Switch to disable the privilege, rather than enable it.
  [Switch] $Disable
 )

 ## Taken from P/Invoke.NET with minor adjustments.
 $definition = @'
 using System;
 using System.Runtime.InteropServices;

 public class AdjPriv
 {
  [DllImport("advapi32.dll", ExactSpelling = true, SetLastError = true)]
  internal static extern bool AdjustTokenPrivileges(IntPtr htok, bool disall,
   ref TokPriv1Luid newst, int len, IntPtr prev, IntPtr relen);

  [DllImport("advapi32.dll", ExactSpelling = true, SetLastError = true)]
  internal static extern bool OpenProcessToken(IntPtr h, int acc, ref IntPtr phtok);
  [DllImport("advapi32.dll", SetLastError = true)]
  internal static extern bool LookupPrivilegeValue(string host, string name, ref long pluid);
  [StructLayout(LayoutKind.Sequential, Pack = 1)]
  internal struct TokPriv1Luid
  {
   public int Count;
   public long Luid;
   public int Attr;
  }

  internal const int SE_PRIVILEGE_ENABLED = 0x00000002;
  internal const int SE_PRIVILEGE_DISABLED = 0x00000000;
  internal const int TOKEN_QUERY = 0x00000008;
  internal const int TOKEN_ADJUST_PRIVILEGES = 0x00000020;
  public static bool EnablePrivilege(long processHandle, string privilege, bool disable)
  {
   bool retVal;
   TokPriv1Luid tp;
   IntPtr hproc = new IntPtr(processHandle);
   IntPtr htok = IntPtr.Zero;
   retVal = OpenProcessToken(hproc, TOKEN_ADJUST_PRIVILEGES | TOKEN_QUERY, ref htok);
   tp.Count = 1;
   tp.Luid = 0;
   if(disable)
   {
    tp.Attr = SE_PRIVILEGE_DISABLED;
   }
   else
   {
    tp.Attr = SE_PRIVILEGE_ENABLED;
   }
   retVal = LookupPrivilegeValue(null, privilege, ref tp.Luid);
   retVal = AdjustTokenPrivileges(htok, false, ref tp, 0, IntPtr.Zero, IntPtr.Zero);
   return retVal;
  }
 }
'@

 $processHandle = (Get-Process -id $ProcessId).Handle
 $type = Add-Type $definition -PassThru
 $type[0]::EnablePrivilege($processHandle, $Privilege, $Disable)
}

# Enable the take ownership functionality
Enable-Privilege SeTakeOwnershipPrivilege


# Set the registry key to work with
$HKLMpath = 'SOFTWARE\Microsoft\Windows NT\CurrentVersion\NetworkList\DefaultMediaCost'
# Change Owner to the local Administrators group
$regKey = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($HKLMpath, [Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree, [System.Security.AccessControl.RegistryRights]::TakeOwnership)
$regACL = $regKey.GetAccessControl()
$regACL.SetOwner([System.Security.Principal.NTAccount]'Administrators')
$regKey.SetAccessControl($regACL)
# Change Permissions for the local SYSTEM account
$regKey = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($HKLMpath, [Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree, [System.Security.AccessControl.RegistryRights]::ChangePermissions)
$regACL = $regKey.GetAccessControl()
$regRule = New-Object System.Security.AccessControl.RegistryAccessRule ('SYSTEM', 'FullControl', 'ContainerInherit', 'None', 'Allow')
$regACL.SetAccessRule($regRule)
$regKey.SetAccessControl($regACL)
# Change Permissions for the local Administrators group
$regRule = New-Object System.Security.AccessControl.RegistryAccessRule ('Administrators', 'FullControl', 'ContainerInherit', 'None', 'Allow')
$regACL.SetAccessRule($regRule)
$regKey.SetAccessControl($regACL)
# Change registry key values for profile defaults

# Set the registry key to work with
$HKLMpath = 'SOFTWARE\Microsoft\Windows NT\CurrentVersion\NetworkList\DefaultMediaCost'
If ($((Get-ItemProperty -ErrorAction Stop -Name '4G' -Path "registry::HKLM\$HKLMpath") | Select-Object -ExpandProperty '4G') -eq 1) {
	Write-Output 'OK' #desired value is existing value
} Else {
	try {
		#Set property value
		Set-ItemProperty -Force -ErrorAction Stop -Name '4G' -Value 1 -Path "registry::HKLM\$HKLMpath"
		Set-ItemProperty -Force -ErrorAction Stop -Name '3G' -Value 1 -Path "registry::HKLM\$HKLMpath"
	} catch {
		#Take ownership of registry key, set permissions, and retry setting property value
		$Owner = 'SYSTEM'
		$regKey = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($HKLMpath, [Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree, [System.Security.AccessControl.RegistryRights]::TakeOwnership)
		$regACL = $regKey.GetAccessControl()
		$regACL.SetOwner([System.Security.Principal.NTAccount]$Owner)
		$regKey.SetAccessControl($regACL)
		# Change Permissions
		$regKey = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($HKLMpath, [Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree, [System.Security.AccessControl.RegistryRights]::ChangePermissions)
		$regACL = $regKey.GetAccessControl()
		$regRule = New-Object System.Security.AccessControl.RegistryAccessRule ($Owner, 'FullControl', 'ContainerInherit', 'None', 'Allow')
		$regACL.SetAccessRule($regRule)
		$regKey.SetAccessControl($regACL)
		#Set property value (retry)
		Set-ItemProperty -Force -ErrorAction Stop -Name '4G' -Value 1 -Path "registry::HKLM\$HKLMpath"
		Set-ItemProperty -Force -ErrorAction Stop -Name '3G' -Value 1 -Path "registry::HKLM\$HKLMpath"
		Write-Output "OK" #remediated
	  }
}

New-ItemProperty -Force -ErrorAction Stop -Name 'PermissionTest' -Value 'Yes' -Path "registry::HKLM\$HKLMpath" -PropertyType String
Remove-ItemProperty -Force -ErrorAction Stop -Name 'PermissionTest' -Path "registry::HKLM\$HKLMpath"

$result = try { Set-ItemProperty -Force -ErrorAction Stop -Name '4G' -Value 1 -Path "registry::HKLM\$HKLMpath" } catch {  }
$result = Set-ItemProperty -Force -ErrorAction SilentlyContinue -Name '3G' -Value 1 -Path "registry::HKLM\$HKLMpath"


#.Synopsis
#   Set-WindowsNetworkConnectionsAsNonMetered.ps1
#   Set each existing network connection as non-metered
#   Verified working on Wi-Fi profiles
#	Verified NOT working on LAN/Ethernet profiles
#	Not verified on WWAN/5G/4G/3G profiles

#Change each network connection profile to be non-metered
[void][Windows.Networking.Connectivity.NetworkInformation, Windows, ContentType = WindowsRuntime]
$NetConnectionProfiles = [Windows.Networking.Connectivity.NetworkInformation]::GetConnectionProfiles()
ForEach ($NetConnectionProfile in $NetConnectionProfiles) {
	Write-Host "Network profile [$($NetConnectionProfile.ProfileName)] NetworkCostType is $($NetConnectionProfile.GetConnectionCost().NetworkCostType)"
	If ($NetConnectionProfile.IsWlanConnectionProfile -eq $true) { #sets the wirless profile to be NOT metered
		netsh wlan set profileparameter name="$($NetConnectionProfile.ProfileName)" cost=Unrestricted #Fixed
	}
	If ($NetConnectionProfile.IsWlanConnectionProfile -eq $false -and $NetConnectionProfile.IsWWanConnectionProfile -eq $false) {
		#TODO: find a command to set an ethernet/LAN profile to metered/non-metered
	}
}

<#
# Test-IsCurrentNetworkConnectionMetered
# https://stackoverflow.com/questions/57344269/check-if-current-network-connection-is-metered-in-windows-batch-file
# https://gist.github.com/nijave/d657fb4cdb518286942f6c2dd933b472
[void][Windows.Networking.Connectivity.NetworkInformation, Windows, ContentType = WindowsRuntime]
$cost = [Windows.Networking.Connectivity.NetworkInformation]::GetInternetConnectionProfile().GetConnectionCost()
$cost.ApproachingDataLimit -or $cost.OverDataLimit -or $cost.Roaming -or $cost.BackgroundDataUsageRestricted -or ($cost.NetworkCostType -ne 'Unrestricted')
# Test-IsCurrentNetworkConnectionMetered
# https://devblogs.microsoft.com/scripting/more-messing-around-with-wireless-settings-with-powershell/
$connectionProfile = [Windows.Networking.Connectivity.NetworkInformation]::GetInternetConnectionProfile()
$connectionCost = $connectionProfile.GetConnectionCost()
$networkCostType = $connectionCost.NetworkCostType
#>
