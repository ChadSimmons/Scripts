### !!! Customize region Environment specific variables !!! ###
#
#.Synopsis
#   Invoke-TS_Initialize.ps1
#   Set built-in and custom SCCM Task Sequence Variable defaults.
#   Replaces MDT Gather step during OS deployment
#   This should be run at the beginning of a Task Sequence before any real actions occur
#.Description
#    Run in SCCM Task Sequence as lightweight replacement for MDT Gather Step
#    Creates and sets a limited number of MDT Task Sequence variables and custom variables
#
#    This is designed for and tested with PowerShell 2.0 for backwards compatibility with Windows 7 SP1
#.Parameter Quiet
#    Suppressed writing the Variables and Values to standard out
#.Parameter SkipSystemInfoExe
#   Switch to prevent running SystemInfo.exe and rely only on created variables for System Info output
#.Parameter SkipSystemInfoUpload
#   Switch to prevent uploading SystemInfo results to a server share
#.Parameter UseLenovoModelName
#    Replaces Lenovo's Computer Model with the Model Name from the WMI Win32_ComputerSystemProduct class' Version property
#.Example
#    PowerShell.exe -ExecutionPolicy Bypass -File Invoke-TS_Initialize.ps1 -Quiet
#.Notes
#	========== Change Log History ==========
#	- 2019/08/14 by Chad.Simmons@CatapultSystems.com - Updated Function Get-NICEthernetConnectionInfo to refine wired connection status inconsistencies
#	- 2019/08/08 by Chad.Simmons@CatapultSystems.com - Replaced Function Get-NICAdapterInfo with Get-NICEthernetConnectionInfo to correct wired connection status inconsistencies
#	- 2019/07/12 by Chad.Simmons@CatapultSystems.com - reworked Set-Var and Output routines to address seemingly random issues
#	- 2019/06/12 by Chad.Simmons@CatapultSystems.com - added -Alias to Set-Var to better support mirroring MDT Variable Names as well as standardized zTS_ names
#	- 2019/06/06 by Chad.Simmons@CatapultSystems.com - added Get-TPMInfo, reworked BiosInfo, NICConfigurationInfo and NICAdapterInfo
#	- 2019/05/15 by Chad.Simmons@CatapultSystems.com - rewrote completely
#	- 2018/10/17 by Johan Schrewelius, Onevinn AB - Created https://gallery.technet.microsoft.com/PowerShell-script-that-a8a7bdd8
#	=== To Do / Proposed Changes ===
#   TODO: add exclusions for safe and readable export
#   TODO: get logged on user for a non-Task Sequence environment
#   TODO: Add all variables set by MDT's gather
#         https://thedesktopteam.com/raphael/sccm-script-to-get-some-mdt-variables
#         https://www.hayesjupe.com/sccm-and-mdt-list-of-variables/
#         https://wetterssource.com/gather-script-replace-mdt    and    https://github.com/paulwetter/WettersSource/tree/master/GatherScript    --- using VBScript instead of PowerShell
#   TODO: Add Test-RestartPending
#         HKLM:Software\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending
#         HKLM:SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired
#         HKLM:SYSTEM\CurrentControlSet\Control\Session Manager, PendingFileRenameOperations
#         HKLM:Software\Microsoft\ServerManager, CurrentRebootAttempts
#         Windows Update Agent method
#         SCCM Client Method
#   TODO: Test SCCM MP Connectivity... Get-WmiObject -Namespace 'root\CCM' -Class 'SMS_Authority' | ForEach-Object { $_.CurrentManagementPoint | Test-NetConnection -InformationLevel Quiet -CommonTCPPort HTTP }
#   TODO: Load Process Environment Variables into $TSvars as zPenv_*
#   TODO: Load System Environment Variables into $TSvars as zSenv_*
#   TODO: Load User Environment Variables into $TSvars as zUenv_*
#	=== Additional Notes and References ===
#   Based on MDT Lite from https://garytown.com/so-long-mdt-native-cm-for-me
#            http://gerryhampsoncm.blogspot.com/2017/03/configmgr-osd-use-mdt-without-using-mdt.html
#            Gather https://gallery.technet.microsoft.com/PowerShell-script-that-a8a7bdd8
[CmdletBinding()]
param (
    [switch]$Quiet,
    #[switch]$Debug,
    [switch]$SkipSystemInfoExe,
    [switch]$SkipSystemInfoUpload,
    [switch]$UseLenovoModelName,
    [string]$LogFile,
    [string]$TSType
)

#region ====== Dot source the Function Library ====================================================
If ($PSise) { $global:ScriptFile = $PSise.CurrentFile.FullPath
   } Else { $global:ScriptFile = $MyInvocation.MyCommand.Definition }
# Dot source the Function Library.  Abort if dot-sourcing failed
try { ."$(Split-Path -Path $global:ScriptFile -Parent)\Invoke-TS_Functions.ps1"
    } catch { Write-Error "dot-sourcing function library failed from folder [$global:ScriptPath]"; throw $_; exit 2 }
#endregion === Dot source the Function Library ====================================================

########################################################################################################################################################################################################
Function Get-ComputerSystemProductInfo {
    $Info = Get-WmiObject -Namespace 'root\CIMv2' -Class 'Win32_ComputerSystemProduct' -Property UUID,Vendor,Name,Version
    Set-Var -Name 'zTS_ComputerUUID' -Value $Info.UUID -Alias 'UUID'
    Set-Var -Name 'zTS_ComputerManufacturer' -Value $Info.Vendor -Alias 'Vendor'
    Set-Var -Name 'zTS_ComputerModelNumber' -Value $Info.Name
    If ($Info.Vendor -eq 'LENOVO') {
        Set-Var -Name 'zTS_ComputerModelName' -Value $Info.Version
    } else {
        Set-Var -Name 'zTS_ComputerModelName' -Value $Info.Name
    }
    If ($UseLenovoModelName) {
        Set-Var -Name 'zTS_ComputerModel' -Value $TSvars['zTS_ComputerModelName'] -Alias 'Model'
    } else {
		Set-Var -Name 'zTS_ComputerModel' -Value $TSvars['zTS_ComputerModelNumber'] -Alias 'Model'
    }
    if ($VirtualHosts.ContainsKey($TSvars['zTS_ComputerModel'])) {
        Set-Var -Name 'zTS_ComputerIsVM' -Value 'True' -Alias 'IsVM'
        Set-Var -Name 'zTS_ComputerVMPlatform' -Value $VirtualHosts[$TSvars['zTS_ComputerModel']] -Alias 'VMPlatform'
    } else {
        Set-Var -Name 'zTS_ComputerIsVM' -Value 'False' -Alias 'IsVM'
        Set-Var -Name 'zTS_ComputerVMPlatform' -Value '' -Alias 'VMPlatform'
    }
}
Function Get-ComputerSystemInfo {
    $Info = Get-WmiObject -Namespace 'root\CIMv2' -Class 'Win32_ComputerSystem' -Property 'TotalPhysicalMemory'
    Set-Var -Name 'zTS_ComputerMemoryMB' -Value $([int]($Info.TotalPhysicalMemory / 1024 / 1024).ToString()) -Alias 'Memory'
}
Function Get-ProductInfo {
    $Info = Get-WmiObject -Namespace 'root\CIMv2' -Class 'Win32_BaseBoard' -Property 'Product'
    Set-Var -Name 'zTS_BaseBoardProduct' -Value $Info.Product -Alias 'Product'
}
Function Get-BiosInfo {
    $Info = Get-WmiObject -Namespace 'root\CIMv2' -Class 'Win32_BIOS' -Property SerialNumber,SMBIOSBIOSVersion,ReleaseDate
    Set-Var -Name 'zTS_BIOSSerialNumber' -Value $Info.SerialNumber -Alias 'SerialNumber'
    Set-Var -Name 'zTS_BIOSVersion' -Value $Info.SMBIOSBIOSVersion -Alias 'BIOSVersion'
    Set-Var -Name 'zTS_BIOSReleaseDate' -Value $Info.ReleaseDate -Alias 'BIOSReleaseDate'
    Set-Var -Name 'zTS_BIOSReleaseDateTimestamp' -Value $([System.Management.ManagementDateTimeConverter]::ToDateTime($Info.ReleaseDate))

	# First method, one-liner, extract answer from setupact.log using Select-String and tidy-up with -replace
	# Look in the setup logfile to see what bios type was detected (EFI or BIOS)
    If (Test-Path -Path "$env:SystemRoot\Panther\SetupAct.log") {
        $BIOSTypeFromSetupActLog = (Select-String  -Pattern 'Detected boot environment' -Path "$env:SystemRoot\Panther\SetupAct.log" -AllMatches ).line -replace '.*:\s+'
    }

	Function IsUEFI {
	<#
	.Synopsis
	   Determines underlying firmware (BIOS) type and returns True for UEFI or False for legacy BIOS.
	.DESCRIPTION
	   This function uses a complied Win32 API call to determine the underlying system firmware type.
	.EXAMPLE
	   If (IsUEFI) { # System is running UEFI firmware... }
	.OUTPUTS
	   [Bool] True = UEFI Firmware; False = Legacy BIOS
	.FUNCTIONALITY
	   Determines underlying system firmware type
	#>
	[OutputType([Bool])]
	Param ()
	Add-Type -Language CSharp -TypeDefinition @'
		using System;
		using System.Runtime.InteropServices;
		public class CheckUEFI {
			[DllImport("kernel32.dll", SetLastError=true)]
			static extern UInt32
			GetFirmwareEnvironmentVariableA(string lpName, string lpGuid, IntPtr pBuffer, UInt32 nSize);
			const int ERROR_INVALID_FUNCTION = 1;
			public static bool IsUEFI() {
				// Try to call the GetFirmwareEnvironmentVariable API.  This is invalid on legacy BIOS.
				GetFirmwareEnvironmentVariableA("","{00000000-0000-0000-0000-000000000000}",IntPtr.Zero,0);
				if (Marshal.GetLastWin32Error() == ERROR_INVALID_FUNCTION)
					return false;     // API not supported; this is a legacy BIOS
				else
					return true;      // API error (expected) but call is supported.  This is UEFI.
			}
		}
'@
		[CheckUEFI]::IsUEFI()
	}
	If (IsUEFI -eq $true) { $BIOSTypeFromKernel32 = 'UEFI' } else { $BIOSTypeFromKernel32 = 'BIOS' }

	Function Get-BiosType {
		#.Synopsis
		#  Determines underlying firmware (BIOS) type and returns an integer indicating UEFI, Legacy BIOS or Unknown.
		#  Supported on Windows 8/Server 2012 or later
		#.DESCRIPTION
		#  This function uses a complied Win32 API call to determine the underlying system firmware type.
		#.EXAMPLE
		#  If (Get-BiosType -eq 1) { # System is running UEFI firmware... }
		#.EXAMPLE
		#  Switch (Get-BiosType) {
		#  	1       {"Legacy BIOS"}
		#  	2       {"UEFI"}
		#  Default {"Unknown"}
		#  }
		#.OUTPUTS
		#  Integer indicating firmware type (1 = Legacy BIOS, 2 = UEFI, Other = Unknown)
		#.FUNCTIONALITY
		#  Determines underlying system firmware type
		[OutputType([UInt32])]
		Param()
		Add-Type -Language CSharp -TypeDefinition @'
			using System;
			using System.Runtime.InteropServices;
			public class FirmwareType {
				[DllImport("kernel32.dll")]
				static extern bool GetFirmwareType(ref uint FirmwareType);
				public static uint GetFirmwareType() {
					uint firmwaretype = 0;
					if (GetFirmwareType(ref firmwaretype))
						return firmwaretype;
					else
						return 0;   // API call failed, just return 'unknown'
				}
			}
'@
	#TODO:	[FirmwareType]::GetFirmwareType()
	}
	Switch (Get-BiosType) {
		1 { $BIOSTypeFromFirmware = 'BIOS'}
      	2 { $BIOSTypeFromFirmware = 'UEFI'}
        Default { $BIOSTypeFromFirmware = 'UNKNOWN'}
    }

	If ($BIOSTypeFromSetupActLog -eq 'UEFI' -or $BIOSTypeFromKernel32 -eq 'UEFI' -or $BIOSTypeFromFirmware -eq 'UEFI') {
		Set-Var -Name 'zTS_BIOSType' -Value 'UEFI'
	} Else {
		Set-Var -Name 'zTS_BIOSType' -Value 'Legacy BIOS'
    }

    $UEFISecureBootEnabled = try { Get-ItemPropertyValue -Path 'HKLM:SYSTEM\CurrentControlSet\Control\SecureBoot\State' -Name 'UEFISecureBootEnabled' -ErrorAction Stop } catch {}
    If (($UEFISecureBootEnabled).'UEFISecureBootEnabled' -eq 1) {
        Set-Var -Name 'zTS_UEFISecureBootEnabled' -Value $true
    } Else {
        Set-Var -Name 'zTS_UEFISecureBootEnabled' -Value $false
    }
}
Function Get-OsInfo {
    # $Info = Get-WMIObject -class Win32_OperatingSystem | Select OperatingSstemSKU, OSType, OSProductSuite, ProductType, SystemDevice, SystemDirectory, SystemDrive, BuildType, CurrentTimeZone
    $Info = Get-WmiObject -Namespace 'root\CIMv2' -Class 'Win32_OperatingSystem'
    Set-Var -Name 'zTS_OSName' -Value $Info.Caption
    Set-Var -Name 'zTS_OSVersion' -Value $Info.Version -Alias 'OSCurrentVersion'
    Set-Var -Name 'zTS_OSBuild' -Value $Info.BuildNumber -Alias 'OSCurrentBuild'
    Set-Var -Name 'zTS_OSArchitecture' -Value $Info.OSArchitecture
    Set-Var -Name 'zTS_OSRegisteredOrganization' -Value $Info.Organization
    Set-Var -Name 'zTS_OSRegisteredUser' -Value $Info.RegisteredUser
    Set-Var -Name 'zTS_OSInstallDate' -Value $Info.InstallDate
    Set-Var -Name 'zTS_OSInstallDatestamp' -Value $([System.Management.ManagementDateTimeConverter]::ToDateTime($Info.InstallDate))
    Set-Var -Name 'zTS_OSLastBootUpTime' -Value $Info.LastBootUpTime
    Set-Var -Name 'zTS_OSLastBootUpTimestamp' -Value $([System.Management.ManagementDateTimeConverter]::ToDateTime($Info.LastBootUpTime))
    Set-Var -Name 'zTS_OSBootDevice' -Value $Info.BootDevice
    Set-Var -Name 'zTS_OSSKU' -Value $Info.OperatingSytemSKU
    Set-Var -Name 'zTS_OSType' -Value $Info.OSType
    Set-Var -Name 'zTS_OSProductSuite' -Value $Info.OSProductSuite
    Set-Var -Name 'zTS_OSProductType' -Value $Info.ProductType
    Set-Var -Name 'zTS_OSSystemDevice' -Value $Info.SystemDevice
    Set-Var -Name 'zTS_OSSystemDirectory' -Value $Info.SystemDirectory
    Set-Var -Name 'zTS_OSSystemDrive' -Value $Info.SystemDrive
    Set-Var -Name 'zTS_OSBuildType' -Value $Info.BuildType
    Set-Var -Name 'zTS_OSCurrentTimeZone' -Value $Info.CurrentTimeZone
}
Function Get-SystemEnclosureInfo {
    #If a laptop is docked there will be 2 class instances
    $Info = Get-WmiObject -Namespace 'root\CIMv2' -Class 'Win32_SystemEnclosure' -Property SMBIOSAssetTag,ChassisTypes | Where-Object {$_.ChassisTypes -notcontains 12} | Select-Object -First 1
    Set-Var -Name 'zTS_BIOSAssetTag' -Value $Info.SMBIOSAssetTag
    $Info.ChassisTypes | Where-Object {$_ -notcontains 12} | ForEach-Object {
        Set-Var -Name 'zTS_ComputerChassisID' -Value $_.ToString()
        if ($TSvars.ContainsKey('zTS_ComputerIsDesktop')) {
            Set-Var -Name 'zTS_ComputerIsDesktop' -Value [string]$DesktopChassisTypes.Contains($_.ToString()) -Force -Alias 'IsDesktop'
            Set-Var -Name 'zTS_ComputerChassisType' -Value 'Desktop'
        }
        if ($TSvars.ContainsKey('zTS_ComputerIsLaptop')) {
            Set-Var -Name 'zTS_ComputerIsLaptop' -Value [string]$LaptopChassisTypes.Contains($_.ToString()) -Force -Alias 'IsLaptop'
            Set-Var -Name 'zTS_ComputerChassisType' -Value 'Laptop'
        }
        if ($TSvars.ContainsKey('zTS_ComputerIsServer')) {
            Set-Var -Name 'zTS_ComputerIsServer' -Value [string]$ServerChassisTypes.Contains($_.ToString()) -Force -Alias 'IsServer'
            Set-Var -Name 'zTS_ComputerChassisType' -Value 'Server'
        }
    }
}
Function Get-NICConfigurationInfo {
    (Get-WmiObject -Namespace 'root\CIMv2' -Class 'Win32_NetworkAdapterConfiguration' -Filter 'IPEnabled = 1') | ForEach-Object {
        $_.IPAddress | ForEach-Object {
            #TODO: log NIC name/description/servicename as well
            if($null -ne $_) {
                if($_.IndexOf('.') -gt 0 -and !$_.StartsWith('169.254') -and $_ -ne '0.0.0.0') {
                    if($TSvars.ContainsKey('zTS_IPAddress')) {
                        Set-Var -Name 'zTS_IPAddresses' -Value $($TSvars['zTS_IPAddress'] + ',' + $_) -Force -Alias 'IPAddress'
                    } else {
                        Set-Var -Name 'zTS_IPAddresses' -Value $_ -Alias 'IPAddress'
                    }
                }
            }
        }
        $_.IPSubnet | ForEach-Object {
            if($null -ne $_ -and $_.IndexOf('.') -gt 0) {
                if($TSvars.ContainsKey('zTS_IPSubnet')) {
                    Set-Var -Name 'zTS_IPSubnet' -Value $($TSvars['zTS_IPSubnet'] + ',' + $_) -Force
                } else {
                    Set-Var -Name 'zTS_IPSubnet' -Value $_
                }
            }
        }
        $_.DefaultIPGateway | ForEach-Object {
            if($null -ne $_ -and $_.IndexOf('.') -gt 0) {
                if($TSvars.ContainsKey('zTS_DefaultGateway')) {
                    Set-Var -Name 'zTS_DefaultGateway' -Value $($TSvars['zTS_DefaultGateway'] + ',' + $_) -Force -Alias 'DefaultGateway'
                } else {
                    Set-Var -Name 'zTS_DefaultGateway' -Value $_ -Alias 'DefaultGateway'
                }
            }
        }
        $_.MacAddress | ForEach-Object {
            if($null -ne $_ -and $_.IndexOf('.') -gt 0) {
                if($TSvars.ContainsKey('zTS_MacAddresses')) {
                    Set-Var -Name 'zTS_MacAddresses' -Value $($TSvars['zTS_MacAddresses'] + ',' + $_) -Force -Alias 'MacAddress'
                } else {
                    Set-Var -Name 'zTS_MacAddresses' -Value $_ -Alias 'MacAddress'
                }
            }
        }
    }
}
Function Get-NICEthernetConnectionInfo {
    #.Synopsis Determine if connected by wired Etherenet
    #https://weblogs.sqlteam.com/mladenp/2010/11/04/find-only-physical-network-adapters-with-wmi-win32_networkadapter-class/
    #https://stackoverflow.com/questions/10114455/determine-network-adapter-type-via-wmi
    #http://blogs.technet.com/b/heyscriptingguy/archive/2014/01/12/weekend-scripter-use-powershell-to-identify-network-adapter-characteristics.aspx#comments
    $WiredNICNames = @((Get-WmiObject -Namespace 'root\WMI' -Class 'MSNdis_PhysicalMediumType' -Filter 'NdisPhysicalMediumType = 0 and Active = "true"' -Property InstanceName | Where-Object { $_.InstanceName -notmatch 'RAS|ISATAP|Teredo|6to4' }).InstanceName)
    Write-LogMessage -Message "Wired NIC Names: $($WiredNICNames -join '; ')"
    Set-Var -Name 'zTS_NICs_Wired' -Value $($WiredNICNames -join '; ')
    $IPEnabledNICs = @(Get-WmiObject -Class Win32_NetworkAdapterConfiguration -Filter 'IPEnabled="True"' | Select-Object Description, Caption, ServiceName, MACAddress) #IPAddress
    Write-LogMessage -Message "IP Enabled NICs: $($IPEnabledNICs.Description -join '; ')"
    Set-Var -Name 'zTS_NICs_IPEnabled' -Value $($IPEnabledNICs.Description -join '; ')
    #https://docs.microsoft.com/en-us/windows/desktop/CIMWin32Prov/Win32-NetworkAdapter
    #NetConnectionStatus is Connected, AdapterType is Ethernet (wired and wireless/WiFi), Availability is Running/Full Power, Installed is True, NetEnable is true
    #Return the NICs that are connected, Ethernet (wired and wireless/WiFI), Installed, and Enabled.  This SHOULD only get wired ethernet...
    $NetAdapters = @(Get-WmiObject -Namespace 'root\CIMv2' -Class 'Win32_NetworkAdapter' -Filter 'NetConnectionStatus = 2 and AdapterType = "Ethernet 802.3" and Availability = 3 and Installed = "true" and NetEnabled = "true"')
    Write-LogMessage -Message "All Ethernet Adapters: $($NetAdapters.Name -join '; ')"
    Set-Var -Name 'zTS_NICs_Ethernet' -Value $($NetAdapters.Name -join '; ')
    $NetAdapters = $NetAdapters | Where-Object { $_.Description -notlike '*VMware*' -and $_.Description -notlike '*vmxnet*'-and $_.Description -notlike '*wireless*' -and $_.Description -notlike '*WiFi*' -and $_.Description -notlike '*bluetooth*' -and $_.Description -notlike '* wimax *' -and $_.Description -notlike '*wan *'}
    #-and $_.Caption -notlike '*wireless*' -and $_.Description -notlike '*wireless*' -and $_.ProductName -notlike '*wireless*' -and $_.Name -notlike '*wireless*' -and $_.NetConnectionID -notlike '*wireless*' -and $_.NetConnectionID -notlike '*WiFi*' -and $_.NetConnectionID -notlike '*Wi-Fi*' -and $_.Name -notlike '*bluetooth*' -and $_.Name -notlike '* wimax *' -and $_.Name -notlike '*wan *'}
    #$NetAdapters = $NetAdapters | Where-Object { $_.Description -notmatch 'VMware|vmxnet' -and $_.Caption -notmatch 'wireless|WiFi|Wi-Fi|bluetooth|wimax|wan' -and $_.Description -notmatch 'wireless|WiFi|Wi-Fi|bluetooth|wimax|wan' -and $_.ProductName -notmatch 'wireless|WiFi|Wi-Fi|bluetooth|wimax|wan' -and $_.Name -notmatch 'wireless|WiFi|Wi-Fi|bluetooth|wimax|wan' -and $_.NetConnectionID -notmatch 'wireless|WiFi|Wi-Fi|bluetooth|wimax|wan'}
    Write-LogMessage -Message "non-Excluded Ethernet Adapters: $($NetAdapters.Name -join '; ')"
    Set-Var -Name 'zTS_NICs_Ethernet_nonExcluded' -Value $($NetAdapters.Name -join '; ')

    #If (($NetAdapters.Name -contains $WiredNICNames -or $WiredNICNames -contains $NetAdapters.Name) -and ($IPEnabledNICs.Description -contains $WiredNICNames -or $WiredNICNames -contains $IPEnabledNICs.Description)) {
	#	Set-Var -Name 'zTS_EthernetConnected' -Value $true
	#} else {
	#	Set-Var -Name 'zTS_EthernetConnected' -Value $false
    #}

    $EthernetConnected = $false
    $EthernetConnectedNIC = $null
    ForEach ($IPEnabledNIC in $IPEnabledNICs.Description) {
        ForEach ($WiredNICName in $WiredNICNames) {
            ForEach ($NetAdapter in $NetAdapters.Name) {
                If ($WiredNICName -eq $IPEnabledNIC -and $WiredNICName -eq $NetAdapter) {
                    $EthernetConnected = $true
                    $EthernetConnectedNIC = $WiredNICName
                    Write-LogMessage -Message "Found NIC [$WiredNICName] matches all criteria for active online wired Ethernet"
                    Set-Var -Name 'zTS_EthernetConnectedNIC' -Value $WiredNICName #Write-Output "EthernetConnectNIC = $WiredNICName"
                }
            }
        }
    }
    Set-Var -Name 'zTS_EthernetConnected' -Value $EthernetConnected
    Write-Verbose -Message "EthernetConnected is [$EthernetConnected]"
    If ([string]::IsNullOrEmpty($EthernetConnectedNIC)) {
        Write-LogMessage -Message "No NIC matches all criteria for active online wired Ethernet"
    }
}
Function Get-BatteryStatusInfo {
    try {
        $AcConnected = (Get-WmiObject -Namespace 'root\wmi' -Query 'SELECT PowerOnline FROM BatteryStatus Where Voltage > 0' -ErrorAction SilentlyContinue).PowerOnline
    } catch { }
    if ($null -eq $AcConnected) {
        $AcConnected = 'True'
    }
    Set-Var -Name 'zTS_BatteryIsOn' -Value ((![bool]$AcConnected)).ToString() -Alias 'IsOnBattery'
    Set-Var -Name 'zTS_ACPowerIsOn' -Value (([bool]$AcConnected)).ToString()
}
Function Get-BatteryInfo {
    #https://docs.microsoft.com/en-us/windows/desktop/CIMWin32Prov/win32-battery
    #Availability : 2 = unknown / plugged-in, 3 = Running/Full Power
    #BatteryStatus : 1 = discharging, 2 = plugged-in, 6 = charging, 7 = charging and high, 11 = partially charged
    #EstimatedChargeRemaining (%)
    #EstimatedRuntTime (minutes)
    try {
        $Info = Get-WmiObject -Namespace 'root\CIMv2' -Class 'Win32_Battery' -Property Availability,BatteryStatus,EstimatedChargeRemaining,EstimatedRunTime -ErrorAction Stop
    } catch {
        #if running in WinPE...
        try {
            $TSenv = New-Object -ComObject Microsoft.SMS.TSEnvironment
            If ($TSenv.Value('_SMSTSInWinPE') -eq 'true') {
                drvload.exe X:\Windows\INF\Battery.inf
                $Info = Get-WmiObject -Namespace 'root\CIMv2' -Class 'Win32_Battery' -ErrorAction Stop
            }
        } catch { }
    }
    If ($Info) {
        Set-Var -Name 'zTS_BatteryAvailability' -Value $Info.Availability
        Set-Var -Name 'zTS_BatteryStatus' -Value $Info.BatteryStatus
        Set-Var -Name 'zTS_BatteryEstimatedRunTime' -Value $Info.EstimatedRunTime
        Try {
        Set-Var -Name 'zTS_BatteryEstimatedChargeRemaining' -Value $Info.EstimatedChargeRemaining
        Set-Var -Name 'zTS_BatteryChargeIsLow' -Value If ($Info.EstimatedChargeRemaining -lt 65) { $true } else { $false }
        Set-Var -Name 'zTS_BatteryChargeIsCriticallyLow' -Value If ($Info.EstimatedChargeRemaining -lt 25) { $true } else { $false }
        } catch {}
    }
}
Function Get-ArchitectureInfo {
    if ($env:PROCESSOR_ARCHITECTURE.Equals('AMD64')) {
        Set-Var -Name 'zTS_ProcArchitecture' -Value 'x64' -Alias 'Architecture'
    } else {
        Set-Var -Name 'zTS_ProcArchitecture' -Value 'x86' -Alias 'Architecture'
    }
}
Function Get-ProcessorInfo {
    $Info = @(Get-WmiObject -Namespace 'root\CIMv2' -Class 'Win32_Processor' -Property MaxClockSpeed)
    Set-Var -Name 'zTS_ProcessorSpeed' -Value $($Info | Select-Object -First 1).MaxClockSpeed.ToString() -Alias 'ProcessorSpeed'
    Set-Var -Name 'zTS_ProcessorCount' -Value $Info.count
}
Function Get-BitLockerInfo {
    $IsBDE = $false
    $BitlockerEncryptionType = 'N/A'
    $BitlockerEncryptionMethod = 'N/A'
    try {
        $EncVols = Get-WmiObject -Namespace 'root\CIMv2\Security\MicrosoftVolumeEncryption' -Class 'Win32_EncryptableVolume' -ErrorAction Stop
    } catch {
        If ((Test-Path -Path "$env:WinDir\system32\wbem\win32_encryptablevolume.mof" -PathType Leaf) -and (Test-Path -Path "$env:WinDir\mofcomp.exe" -PathType Leaf)) {
            mofcomp.exe c:\windows\system32\wbem\win32_encryptablevolume.mof
            $EncVols = Get-WmiObject -Namespace 'root\CIMv2\Security\MicrosoftVolumeEncryption' -Class 'Win32_EncryptableVolume' -ErrorAction SilentlyContinue
        }
    }
    If ($EncVols) {
        If ($EncVols | Where-Object { $_.Driveletter -eq 'c:' -and $_.protectionstatus -eq '1'}) { Set-Var -Name 'OSDBitLockerStatus' -Value 'Protected' }
        foreach ($EncVol in $EncVols) {
            if($EncVol.ProtectionStatus -ne 0) {
                $EncMethod = [int]$EncVol.GetEncryptionMethod().EncryptionMethod
                if ($EncryptionMethods.ContainsKey($EncMethod)) {
                    $BitlockerEncryptionMethod = $EncryptionMethods[$EncMethod]
                }
                $Status = $EncVol.GetConversionStatus(0)
                if ($Status.ReturnValue -eq 0) {
                    if ($Status.EncryptionFlags -eq 0x00000001) {
                        $BitlockerEncryptionType = 'Used Space Only Encrypted'
                    } else {
                        $BitlockerEncryptionType = 'Full Disk Encryption'
                    }
                } else {
                    $BitlockerEncryptionType = 'Unknown'
                }
                $IsBDE = $true
            }
        }
    }
    Set-Var -Name 'zTS_IsBDE' -Value $IsBDE.ToString() -Alias 'IsBDE'
	Set-Var -Name 'zTS_BitLockerIsEnabled' -Value $IsBDE.ToString()
    Set-Var -Name 'zTS_BitlockerEncryptionMethod' -Value $BitlockerEncryptionMethod -Alias 'BitlockerEncryptionMethod'
    Set-Var -Name 'zTS_BitlockerEncryptionType' -Value $BitlockerEncryptionType -Alias 'BitlockerEncryptionType'
}
Function Get-LoggedOnUser {
    #.Link https://garytown.com/gather-user-account-name-during-ipu
    #.Synopsis Get Logged On User and place into TS Variable, if the TS was initiated by a user
    #.Note
    #   Most of code to get the user was stolen from: https://gallery.technet.microsoft.com/scriptcenter/0e43993a-895a-4afe-a2b2-045a5146048a
    #   Modified by @gwblok (GARYTOWN.COM)
    #   This script is designed to be used with the SetInfo Script for WaaS https://garytown.com/collect-osd-ipu-info-with-hardware-inventory
    try {
        $TSenv = New-Object -COMObject Microsoft.SMS.TSEnvironment
        if ($tsenv.Value('_SMSTSUserStarted') -eq 'True') {
            $regexa = '.+Domain="(.+)",Name="(.+)"$'
            $regexd = '.+LogonId="(\d+)"$'
            $logon_sessions = @(Get-WmiObject -Namespace 'root\CIMv2' -Class 'Win32_LogonSession')# -Property LogonId,LogonType,AuthenticationPackage)
            $logon_users = @(Get-WmiObject -Namespace 'root\CIMv2' -Class 'Win32_LoggedonUser')# -Property antecedent,dependent)
            $session_user = @{}
            $logon_users | ForEach-Object { $_.antecedent -match $regexa > $nul ;$username = $matches[2] ;$_.dependent -match $regexd > $nul ;$session = $matches[1] ;$session_user[$session] += $username }
            $currentUser = $logon_sessions | ForEach-Object {
                $loggedonuser = New-Object -TypeName psobject
                $loggedonuser | Add-Member -MemberType NoteProperty -Name 'User' -Value $session_user[$_.LogonId]
                $loggedonuser | Add-Member -MemberType NoteProperty -Name 'Type' -Value $_.LogonType
                $loggedonuser | Add-Member -MemberType NoteProperty -Name 'Auth' -Value $_.AuthenticationPackage
                ($loggedonuser  | Where-Object {$_.Type -eq '2' -and $_.Auth -eq 'Kerberos'}).User
            }
            $currentUser = $currentUser | Select-Object -Unique
            Set-Var -Name 'zTS_LoggedOnUserAccount' -Value $CurrentUser
        }
    } catch {
        #TODO: get logged on user for a non-Task Sequence environment
    }
}
Function Get-DiskDriveInfo {
    $Info = @(Get-WmiObject -Namespace 'root\CIMv2' -Class 'Win32_DiskDrive' -Property DeviceID, Partitions, Index, Size, Model, SerialNumber, FirmwareRevision, MediaType)
    Set-Var -Name 'zTS_FixedDiskCount' -Value @($Info | Where-Object { $_.MediaType -eq 'Fixed hard disk media' }).count
    ForEach ($Disk in $Info | Sort-Object Index) {
        Set-Var -Name "zTS_Disk$($Disk.Index)_DeviceID" -Value $Disk.DeviceID
        Set-Var -Name "zTS_Disk$($Disk.Index)_MediaType" -Value $Disk.MediaType
        Set-Var -Name "zTS_Disk$($Disk.Index)_Size" -Value $Disk.Size
        Set-Var -Name "zTS_Disk$($Disk.Index)_Model" -Value ($Disk.Model).trim()
        Set-Var -Name "zTS_Disk$($Disk.Index)_FirmwareRevision" -Value ($Disk.FirmwareRevision).trim()
        If (-not([string]::IsNullOrEmpty($Disk.SerialNumber))) {
            $SN = ($Disk.SerialNumber).toString().trim().split(' ')[0].trim('.')
            If (-not([string]::IsNullOrEmpty($SN))) {
                Set-Var -Name "zTS_Disk$($Disk.Index)_SerialNumber" -Value $SN
            }
            Remove-Variable -Name SN
        }
        Set-Var -Name "zTS_Disk$($Disk.Index)_Partitions" -Value $Disk.Partitions
        #TODO Set-Var -Name 'zTS_Disk'+$Disk.Index+'_ContainsWindows' -Value ???
    }
}
Function Get-DiskPartitionInfo {
    $Info = @(Get-WmiObject -Namespace 'root\CIMv2' -Class 'Win32_DiskPartition' -Property Index, DiskIndex, DeviceID, Size, Bootable, BootPartition, PrimaryPartition, Type)
    #$Info = @($Info | Where-Object { $_.PrimaryPartition -eq $true }
    Set-Var -Name 'zTS_DiskPartitionCount' -Value $Info.count
    ForEach ($Partition in $Info | Sort-Object Index) {
        Set-Var -Name "zTS_Disk$($Partition.DiskIndex)_Partition$($Partition.Index)_DeviceID" -Value $Partition.DeviceID
        Set-Var -Name "zTS_Disk$($Partition.DiskIndex)_Partition$($Partition.Index)_Size" -Value $Partition.Size
        Set-Var -Name "zTS_Disk$($Partition.DiskIndex)_Partition$($Partition.Index)_Bootable" -Value $Partition.Bootable
        Set-Var -Name "zTS_Disk$($Partition.DiskIndex)_Partition$($Partition.Index)_BootPartition" -Value $Partition.BootPartition
        Set-Var -Name "zTS_Disk$($Partition.DiskIndex)_Partition$($Partition.Index)_PrimaryPartition" -Value $Partition.PrimaryPartition
        Set-Var -Name "zTS_Disk$($Partition.DiskIndex)_Partition$($Partition.Index)_Type" -Value $Partition.Type
        #TODO Set-Var -Name 'zTS_Disk'+$Partition.DiskIndex+'_Partition'+$Partition.Index+'_ContainsWindows' -Value ???
    }
}
Function Get-LogicalDiskInfo {
    $Info = @(Get-WmiObject -Namespace 'root\CIMv2' -Class 'Win32_LogicalDisk' -Filter "DriveType=3" -Property DeviceID, Compressed, DriveType, FileSystem, Size, FreeSpace, MediaType, VolumeName, VolumeSerialNumber, VolumeDirty)
    $OSInfo = Get-WmiObject -Namespace 'root\CIMv2' -Class 'Win32_OperatingSystem' -Property SystemDrive
    Set-Var -Name 'zTS_LogicalDiskCount' -Value $Info.count
    ForEach ($Disk in $Info | Sort-Object DeviceID) {
        $Drive = $Disk.DeviceID.ToString().Substring(0,1)
        Set-Var -Name "zTS_LogicalDisk_$($Drive)_DeviceID" -Value $Disk.DeviceID
        Set-Var -Name "zTS_LogicalDisk_$($Drive)_DriveType" -Value $Disk.DriveType
        Set-Var -Name "zTS_LogicalDisk_$($Drive)_MediaType" -Value $Disk.MediaType
        Set-Var -Name "zTS_LogicalDisk_$($Drive)_FileSystem" -Value $Disk.FileSystem
        Set-Var -Name "zTS_LogicalDisk_$($Drive)_Size" -Value $Disk.Size
        Set-Var -Name "zTS_LogicalDisk_$($Drive)_FreeSpace" -Value $Disk.FreeSpace
        Set-Var -Name "zTS_LogicalDisk_$($Drive)_VolumeName" -Value $Disk.VolumeName
        Set-Var -Name "zTS_LogicalDisk_$($Drive)_VolumeSerialNumber" -Value $Disk.VolumeSerialNumber
        Set-Var -Name "zTS_LogicalDisk_$($Drive)_VolumeDirty" -Value $Disk.VolumeDirty
        Set-Var -Name "zTS_LogicalDisk_$($Drive)_Compressed" -Value $Disk.Compressed
        If ($Disk.DeviceID -eq $OSInfo.SystemDrive) {
            Set-Var -Name "zTS_LogicalDisk_$($Drive)_ContainsWindows" -Value $true
            Set-Var -Name 'zTS_OSDrive_FreespaceGB' -Value $([math]::Round($Disk.Freespace / 1024 / 1024 / 1024, 0))
            Set-Var -Name 'zTS_OSDrive_FreespaceForWaaS' -Value $(If ($Disk.Freespace -gt 20000000000) { $true } else { $false })
        }
    }
}
Function Get-TPMInfo {
	#.Synopsis
	#  Get TPM and BitLocker Status
	#.LINK
	#  See Inventory-TPMstate.ps1
	#  https://community.spiceworks.com/topic/1717997-bitlocker-status-into-sccm-task-sequence-variable
	#  http://blog-en.netvnext.com/2013/03/check-for-tpm-before-enabling-bitlocker.html -> not sufficient
	$Status = @{TPMIsEnabled = 'False'; TPMIsOwned = 'False'; TPMIsActivated = 'False'}
	# Query the WMI of the computer for the status of the TPM chip
    try {
        $Info = Get-WmiObject -Namespace 'root\CIMv2\Security\MicrosoftTpm' -Class Win32_TPM -ErrorAction Stop
        If (($Info.IsEnabled()).IsEnabled -eq 'True') { $Status.TPMIsEnabled = 'True' }
        If (($Info.IsOwned()).IsOwned -eq 'True') { $Status.TPMIsOwned = 'True' }
        If (($Info.IsActivated()).IsActivated -eq 'True') { $Status.TPMIsActivated = 'True' }
    } catch {}
	Set-Var -Name 'zTS_TPMIsEnabled' -Value $Status.TPMIsEnabled
	Set-Var -Name 'zTS_TPMIsOwned' -Value $Status.TPMIsOwned
	Set-Var -Name 'zTS_TPMIsActivated' -Value $Status.TPMIsActivated
}
Function Get-PowerPlan {
    try {
        $Info = Get-WmiObject -Namespace 'root\CIMv2\power' -Class 'Win32_PowerPlan' -Filter {isActive='true'} -Property ElementName -ErrorAction Stop
        Set-Var -Name 'zTS_PowerPlan' -Value $Info.ElementName
    } catch {}
}
Function Get-LanguageAndRegion {
    #$Info = Get-WinSystemLocale
    #Set-Var -Name 'zTS_SystemLocaleDescription' -Value "$($Info.LCID); $($Info.Name); $($Info.DisplayName)"
    #Set-Var -Name 'zTS_SystemLocaleName' -Value $Info.Name
    try {
        #$Info = [cultureinfo]::CurrentCulture
        #Set-Var -Name 'zTS_SystemLocaleDescription' -Value "$($Info.LCID); $($Info.Name); $($Info.DisplayName)"
        #Set-Var -Name 'zTS_SystemLocaleName' -Value $Info.Name
    } catch {}
    try {
        $Info = Get-Culture
        Set-Var -Name 'zTS_InputCultureDescription' -Value "$($Info.LCID); $($Info.Name); $($Info.DisplayName)"
        Set-Var -Name 'zTS_InputCultureName' -Value $Info.Name
    } catch {}
    $Info = Get-WmiObject -Namespace 'root\CIMv2' -Class 'Win32_OperatingSystem'
    Set-Var -Name 'zTS_OSLocale' -Value $Info.Locale
    Set-Var -Name 'zTS_OSLanguage' -Value $Info.OSLanguage
}
Function Get-Timezone {
    #$Info = Get-Timezone
    $Info = [System.TimeZoneInfo]::Local
    Set-Var -Name 'zTS_TimezoneName' -Value $Info.DisplayName
    Set-Var -Name 'zTS_TimezoneID' -Value $Info.ID
    Set-Var -Name 'zTS_TimezoneUTCOffset' -Value $Info.BaseUtcOffset
    $Info = Get-WmiObject -Namespace 'root\CIMv2' -Class 'Win32_OperatingSystem' -Property CurrentTimeZone
    Set-Var -Name 'zTS_OSCurrentTimeZone' -Value $Info.CurrentTimeZone
    #zTS_OSCurrentTimeZone Gets Timezone offset like -360
}
########################################################################################################################################################################################################
Start-Script
$TSvars = @{}
Get-TSenv

$DesktopChassisTypes = @('3','4','5','6','7','13','15','16')
$LaptopChassisTypes = @('8','9','10','11','12','14','18','21','30','31')
$ServerChassisTypes = @('23')
$VirtualHosts = @{'Virtual Machine'='Hyper-V'; 'VMware Virtual Platform'='VMware'; 'VMware7,1'='VMware'; 'VirtualBox'='VirtualBox'; 'Xen'='Xen'}
$EncryptionMethods = @{0 = 'UNSPECIFIED'; 1 = 'AES_128_WITH_DIFFUSER'; 2 = 'AES_256_WITH_DIFFUSER'; 3 = 'AES_128'; 4 = 'AES_256'; 5 = 'HARDWARE_ENCRYPTION'; 6 = 'AES_256'; 7 = 'XTS_AES_256'}

#region    ========== Common Variables
Set-Var -Name 'zTS_StartTime' -Value $(Get-Date -Format 'yyyyMMddHHmmss')
Set-Var -Name 'zTS_StartTimestamp' -Value $(Get-Date -Format 's')

Get-ComputerSystemProductInfo
Get-ComputerSystemInfo
Get-ProductInfo
Get-BiosInfo
Get-OsInfo
Get-SystemEnclosureInfo
Get-NICConfigurationInfo
Get-NICEthernetConnectionInfo
Get-BatteryStatusInfo
Get-BatteryInfo
Get-PowerPlan
Get-ArchitectureInfo
Get-ProcessorInfo
Get-TPMInfo
Get-BitLockerInfo
Get-LoggedOnUser
Get-DiskDriveInfo
Get-DiskPartitionInfo
Get-LogicalDiskInfo
Get-LanguageAndRegion
Get-Timezone

If ($TSType) { Set-Var -Name 'zTS_TSType' -Value $TSType }
Set-Var -Name 'zTS_PowerShellVersion' -Value $PSVersionTable.CLRVersion.ToString()
Set-Var -Name 'zTS_Hostname' -Value $env:ComputerName
Set-Var -Name 'zTS_FinalStatus' -Value 'Started'
Set-Var -Name 'zTS_FinalReturnCode' -Value '999' #Set to Failure, Retry unless reset to Success
Set-Var -Name 'zTS_Async' -Value 'cmd.exe /c start /min' -Alias 'Async'
Set-Var -Name 'zTS_PoSH' -Value 'PowerShell.exe -NoLogo -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass' -Alias 'PoSH'
Set-Var -Name 'SMSTSErrorDialogTimeout' -Value 360 #1440 #172800
Set-Var -Name 'SMSTSPeerDownload' -Value 'True'
Set-Var -Name 'SMSTSAssignUsersMode' -Value 'Auto'
Set-Var -Name 'SMSTSSoftwareUpdateScanTimeout' -Value 3600
Set-Var -Name 'SMSTSAssignmentsDownloadRetry' -Value 5
Set-Var -Name 'SMSTSDownloadRetryCount' -Value 5
Set-Var -Name 'SMSTSDownloadRetryDelay' -Value 2
Set-Var -Name 'SMSTSPersistContent' -Value 'True' #Use this variable to temporarily persist content in the task sequence cache.
Set-Var -Name 'SMSTSPreserveContent' -Value 'False' #Use this variable to keep Configuration Manager client cache after the deployment.
Set-Var -Name 'OSDInputLocale' -Value 'EN-US'
Set-Var -Name 'OSDSystemLocale' -Value 'EN-US'
Set-Var -Name 'OSDUserLocale' -Value 'EN-US'
Set-Var -Name 'OSDUILanguage' -Value 'EN-US'
Set-Var -Name 'OSDUILanguageFallback' -Value 'EN-US'
#endregion ========== Common Variables

#region    ========== Environment specific variables
Set-Var -Name 'zTS_OrgName' -Value 'LAB'
Set-Var -Name 'zTS_LogsServer' -Value 'Server.Contoso.com'
Set-Var -Name 'zTS_LogsShareBasePath' -Value 'Share\Folder\SubFolder'
Set-Var -Name 'zTS_LogsUNCBasePath' -Value "\\$($TSvars['zTS_LogsServer'])\$($TSvars['zTS_LogsShareBasePath'])"
Set-Var -Name 'zTS_LogsPath' -Value $TSvars['zTS_LogsUNCBasePath']
Set-Var -Name 'SMSClientInstallProperties' -Value 'FSP=Server.Contoso.com SMSMP=Server.Contoso.com CCMDEBUGLOGGING=0 CCMLOGLEVEL=1 CCMLOGMAXSIZE=5242880 CCMLOGMAXHISTORY=9 SMSCACHESIZE=20480'

#Set Potential New Computer Name to for laptops to LT-Right(SerialNumber,12)
#If ($TSvars['zTS_ComputerChassisType'] -eq 'Laptop' ) {
#    $ComputerNamePrefix = 'LT'
#    $SNMaxLen = 15 - 1 - ($ComputerNamePrefix).length
#    $SN = (' ' * $SNMaxLen) + (($TSvars['zTS_BIOSSerialNumber']).Replace(' ','').Replace('-',''));
#    Set-Var -Name 'zTS_OSDComputerName' -Value "$($ComputerNamePrefix)-$($SN.substring($SN.length-$SNMaxLen,$SNMaxLen).trim().ToUpper())" -Alias 'zTS_ComputerName'
#} ElseIf ($TSvars['zTS_ComputerChassisType'] -eq 'Desktop' ) {
#    $ComputerNamePrefix = 'WS'
#    $SNMaxLen = 15 - 1 - ($ComputerNamePrefix).length
#    $SN = (' ' * $SNMaxLen) + (($TSvars['zTS_BIOSSerialNumber']).Replace(' ','').Replace('-',''));
#    Set-Var -Name 'zTS_OSDComputerName' -Value "$($ComputerNamePrefix)-$($SN.substring($SN.length-$SNMaxLen,$SNMaxLen).trim().ToUpper())" -Alias 'zTS_ComputerName'
#} Else {
    #Set Potential New Computer Name to OrgName-Right(SerialNumber,10)
    $SNMaxLen = 15 - 1 - ($TSvars['zTS_OrgName']).length
    $SN = (' ' * $SNMaxLen) + (($TSvars['zTS_BIOSSerialNumber']).Replace(' ','').Replace('-',''));
    Set-Var -Name 'zTS_OSDComputerName' -Value "$($TSvars['zTS_OrgName'])-$($SN.substring($SN.length-$SNMaxLen,$SNMaxLen).trim().ToUpper())" -Alias 'zTS_ComputerName'
#}
#endregion ========== Environment specific variables

#region    ========== Copy set variables to Task Sequence environment variables
Copy-HashtableToTSEnv -Hashtable $TSvars
#If (-not($TSenv.Value('OSDComputerName'))) { Set-Var -Name 'OSDComputerName' -Value $tsenv.Value('_SMSTSMachineName') }
#endregion  ========== Copy set variables to Task Sequence environment variables

#region     ========== Output set variables
If (-not($Quiet)) {
    #TODO: add exclusions for safe and readable export
    If ($TSenv) {
        Write-Verbose -Message 'Writing Task Sequence Variables to standard out'
        #$TSenv.Keys | Sort-Object | ForEach-Object { try { Write-Output "$($_) = $($TSenv[$_])" } catch { Write-Output "Failed outputting variable [$_]" } }
        $TSvars.Keys | Sort-Object | ForEach-Object { try { Write-Output "$($_) = $($TSenv[$_])" } catch { Write-Output "Failed outputting variable [$_]" } }
    } Else {
        Write-Verbose -Message 'Writing Script Variables to standard out'
        $TSvars.Keys | Sort-Object | ForEach-Object { try { Write-Output "$($_) = $($TSvars[$_])" } catch { Write-Output "Failed outputting variable [$_]" }  }
    }
}
#endregion  ========== Output set variables

#region    ========== Tag registry
If ($TSenv) {
	try {
        $RegPath = "HKLM:\SOFTWARE\$($TSenv.Value('zTS_OrgName'))\TaskSequences\$($TSenv.Value('_SMSTSPackageID'))"
        New-Item -Path $RegPath -Force | out-null
        New-ItemProperty -Path $RegPath -Name 'StartTime' -Value $TSenv.Value('zTS_StartTime') -PropertyType String -Force -ErrorAction SilentlyContinue | out-null
        New-ItemProperty -Path $RegPath -Name 'StartTimestamp' -Value $TSenv.Value('zTS_StartTimestamp') -PropertyType String -Force -ErrorAction SilentlyContinue | out-null
        New-ItemProperty -Path $RegPath -Name 'TSVersion' -Value $TSenv.Value('zTS_TSVersion') -PropertyType String -Force -ErrorAction SilentlyContinue | out-null
        New-ItemProperty -Path $RegPath -Name 'TSType' -Value $TSenv.Value('zTS_TSType') -PropertyType String -Force -ErrorAction SilentlyContinue | out-null
    } catch { }
}
#endregion ========== Tag registry

#region    ========== Archive existing Task Sequence Logs
@('SMSTS.log','ScanState.log','LoadState.log','NomadBranch.log','SMSTS.DISM-AddDriver.log') | ForEach-Object {
    $FFN = Join-Path -Path $env:SystemRoot -ChildPath "CCM\Logs\$_";
    If (Test-Path -Path $FFN -PathType Leaf) {
        try {
            $F=Get-Item -Path $FFN;
            $FFNnew = "$($F.DirectoryName)\$($F.BaseName)-$(Get-Date -Date $F.LastWriteTime -Format 'yyyyMMdd-HHmmss')$($F.Extension)"
            Move-Item -Path $FFN -Destination $FFNnew -ErrorAction Stop
            Write-Message -Message "Renamed [$FFN] to [$FFNnew]"
        } catch {}
    }
}
#endregion ========== Archive existing Task Sequence Logs

#region    ========== Write SystemInfo to Local Computer and UNC Path
#Output variables of interest
$OutputVars = @('zTS_StartTimestamp','zTS_Hostname','zTS_ComputerName','zTS_OSDComputerName','zTS_ComputerManufacturer','zTS_ComputerModel','zTS_ComputerModelName','zTS_ComputerModelNumber' `
 ,'zTS_BaseBoardProduct','zTS_ComputerChassisID','zTS_ComputerIsVM','zTS_ComputerVMPlatform','zTS_ComputerUUID','zTS_BIOSSerialNumber','zTS_BIOSReleaseDate','zTS_BIOSVersion'`
 ,'zTS_BIOSAssetTag','zTS_BIOSType','zTS_UEFISecureBootEnabled','zTS_EthernetConnected','zTS_IPAddresses','zTS_DefaultGateway','zTS_IPSubnet','zTS_ComputerMemoryMB'`
 ,'zTS_ACPowerIsOn','zTS_BatteryIsOn','zTS_OSName','zTS_OSVersion','zTS_OSBuild','zTS_OSArchitecture','zTS_OSRegisteredOrganization','zTS_OSRegisteredUser','zTS_OSInstallDate','zTS_OSInstallDatestamp'`
 ,'zTS_OSLastBootUpTime','zTS_OSLastBootUpTimestamp','zTS_OSSKU','zTS_OSType','zTS_OSProductSuite','zTS_OSProductType','zTS_OSBootDevice','zTS_OSSystemDevice','zTS_OSSystemDirectory','zTS_OSSystemDrive'`
 ,'zTS_OSBuildType','zTS_OSLacale','zTS_OSLanguage','zTS_OSCurrentTimeZone','zTS_TimezoneName','zTS_TimezoneID','zTS_TimezoneUTCOffset','zTS_DriveC_FreespaceForWaaS','zTS_DriveC_FreespaceGB','zTS_Disk0_Size'`
 ,'zTS_Disk0_FirmwareRevision','zTS_Disk0_Model','zTS_Disk0_SerialNumber','zTS_DiskPartitionCount','zTS_LogicalDiskCount','zTS_FixedDriveCount','zTS_ProcArchitecture'`
 ,'zTS_ProcessorCount','zTS_ProcessorSpeed','zTS_TPMIsActivated','zTS_TPMIsEnabled','zTS_TPMIsOwned','zTS_PowerShellVersion')
#TODO....
# https://docs.microsoft.com/en-us/powershell/scripting/samples/collecting-information-about-computers?view=powershell-5.1
# https://gallery.technet.microsoft.com/scriptcenter/ShowUI-showset-registered-7ad72ce0
#OS Configuration:          Member Server
#Domain:                    Contoso.com                                 HKLM:SYSTEM\CurrentControlSet\Services\Tcpip\Parameters, NV Domain
#Logon Server:              \\VMFPPDC01                                 $env:LogonServer

$SystemInfoLocalFile = Join-Path -Path $env:SystemRoot -ChildPath 'Logs\SystemInfo.txt'
$OutputVarsMaxLength = ($OutputVars | Measure-Object -Maximum -Property Length).Maximum
$stdout += ForEach ($OutputVar in $OutputVars) {
    "$($OutputVar.ToString().Replace('zTS_','').PadRight($OutputVarsMaxLength,' ')) : $($TSvars[$OutputVar])"
}
If (-not($SkipSystemInfoExe)) {
    Write-Message -Message 'Running SystemInfo.exe...'
    #This method is necessary because of the strange nature of SystemInfo's output
    $pinfo = New-Object System.Diagnostics.ProcessStartInfo
    $pinfo.FileName = Join-Path -Path $env:SystemRoot -ChildPath 'System32\SystemInfo.exe'
    If (Test-Path -Path $pinfo.FileName -PathType leaf) {
        #If SystemInfo.exe does not existthis is probably Windows PE
        $pinfo.RedirectStandardError = $true
        $pinfo.RedirectStandardOutput = $true
        $pinfo.UseShellExecute = $false
        $pinfo.Arguments = '/FO LIST'
        $p = New-Object System.Diagnostics.Process
        $p.StartInfo = $pinfo
        $p.Start() | Out-Null
        #If ($null -ne $p.ID) { Write-Verbose -Message "waiting for process $($p.ID) to end"; $p.WaitForExit(15000) | Out-Null } #TODO: this doesn't actually work with SystemInfo as the process never exits automatically
        Start-Sleep -Seconds 1
        $pAbortTime = (Get-Date).AddSeconds(30)
        $stdout += "`n========== SystemInfo.exe output ==========`n"
        $stdout += Do { $SOL = $p.StandardOutput.ReadLine(); $SOL
            #Write-Verbose -Message "$($p.StartTime) : $pAbortTime : $(Get-Date) : $($p.HasExited)"
            #Start-Sleep -Milliseconds 10
        } Until ( $SOL.Contains('Network Card') -or $p.HasExited -eq $true -or (Get-Date) -gt $pAbortTime )
        Start-Sleep -Seconds 1
        $stdout += $p.StandardOutput.ReadToEnd()
        $p.Close() | Out-Null
    }
}
$stdout | Out-File -FilePath $SystemInfoLocalFile -Force -ErrorAction SilentlyContinue
Remove-Variable -Name stdout, p, pinfo, pAbortTime, SOL -ErrorAction SilentlyContinue
#Test Get-Content -Path $SystemInfoLocalFile -ErrorAction SilentlyContinue

#Upload To central logs share
If (-not($SkipSystemInfoUpload)) {
    try {
        try {
            If ($TSenv) {
                If ($null -eq $TSenv.Value('zTS_TSType')) {
                    $SystemInfoServerPath = Join-Path -Path $TSvars['zTS_LogsPath'] -ChildPath "$($TSenv.Value('_SMSTSPackageID'))-Initialized"
                } Else {
                    $SystemInfoServerPath = Join-Path -Path $TSvars['zTS_LogsPath'] -ChildPath "$($TSenv.Value('zTS_TSType'))-$($TSenv.Value('_SMSTSPackageID'))-Initialized"
                }
            }
        } catch {
            $SystemInfoServerPath = Join-Path -Path $TSvars['zTS_LogsPath'] -ChildPath 'SystemInfo'
        }
        Copy-Item -Path $SystemInfoLocalFile -Destination "$SystemInfoServerPath\$($env:ComputerName).SystemInfo.txt" -Force -ErrorAction Stop -ErrorVariable rc
        Write-Message -Message "Copied [$SystemInfoLocalFile] to server share [$SystemInfoServerPath]"
    } catch { Write-Message -Message "Failed to copy [$SystemInfoLocalFile] to server share [$SystemInfoServerPath] with error [$($rc.HResult):$($rc.Message)]" -Type Warn }
}
#endregion ========== Write SystemInfo to Local Computer and UNC Path

Stop-Script