#TODO: get LEDBAT configurations for remote site system servers

Function Get-pwDistributionPointDetails {
    <#
    .SYNOPSIS
    Gets the details of a ConfigMgr Distribution Point

    .DESCRIPTION
    Gets the details of a ConfigMgr Distribution Point

    .PARAMETER SMSProvider
    The ConfigMgr SMSProvider role's NetBIOS name or FQDN

    .PARAMETER SiteCode
    The 3-character ConfigMgr Site code (MMS).

    .PARAMETER ServerName
    The FQDN of the ConfigMgr Distribution Point server

    .PARAMETER AllInfo
    Gather all details, not just common/important details (not yet implemented)

    .PARAMETER SkipRemoteServerDetails
    Do not reach out to the remote server to gather details, only use data from the SMSProvider

    .PARAMETER FilePath
	This is the file that the HTML will be written to.

    .EXAMPLE
    Get-pwDistributionPointDetails -ServerName DP1.contoso.com -SiteCode LAB -SMSProvider CMPrimary.contoso.com -File C:\CMDocumentation\CMDocumentation.html

    .EXAMPLE
    Get-pwDistributionPointDetails -ServerName DP1.contoso.com -SiteCode LAB -SMSProvider CMPrimary.contoso.com -SkipRemoteServerDetails -AllInfo -File C:\CMDocumentation\CMDocumentation.html
    #>
    param (
		$SMSProvider, #TODO SiteCode and SMSProvider values may be included in the DPWmiObject and thus not needed as function parameters
		$SiteCode,
        [parameter()][Alias('DPName','DP')]$ServerName,
		[parameter()][Alias('File')]$FilePath,
		[switch]$AllInfo,
		[switch]$SkipRemoteServerDetails
    )
	#TODO SiteCode and SMSProvider values may be included in the DPWmiObject and thus not needed as function parameters
	$WMIsplat = @{ Namespace = "root\sms\site_$SiteCode"; ComputerName = $SMSProvider }

    $DPInfo = Get-CIMInstance @WMIsplat -ClassName SMS_DistributionPointInfo -Filter "SiteCode = '$SiteCode' and Name = '$ServerName'" -Property *
    If (-not($DPInfo.Name)) { Break }
	[string]$CMDPServerFQDN = $DPInfo.Name
	[string]$CMDPServerName = $CMDPServerFQDN.split('.')[0]
	[string]$CMDPServerDomainName = $CMDPServerFQDN.Substring($CMDPServerFQDN.IndexOf('.') + 1)
	Write-Verbose "$(Get-Date):   Found DP: $CMDPServerFQDN"
	Write-ProgressEx -CurrentOperation "Found DP: $CMDPServerFQDN" -Activity "Distribution Points" -Status "Collecting info from DB and WMI" -Id 3

	$DPResources = Get-CimInstance @WMIsplat -Class SMS_SCI_SysResUse -Filter "RoleName = 'SMS Distribution Point' and SiteCode = '$SiteCode'" -Property *
	#   $DPResources.props | select PropertyName, Value, Value2, Value1 | Format-Table -AutoSize
	#Build a hashtable for each value pair of DP props for both "Value/Value0" and "Value1" where info is actually stored.  This method is much faster than multiple where clauses
	#   Create a hashtable for speed #https://stackoverflow.com/questions/51895692/speed-up-where-object-comparison-with-csv-files
	#   Get reserved disk space / MinFreeSpace info  https://forums.prajwaldesai.com/threads/change-reserved-disk-space-on-distribution-point.2907/
	$DPPropsValue0 = @{}
	$DPPropsValue1 = @{}
	$DPResources.props | ForEach-Object { $DPPropsValue0[$_.PropertyName] = $_.Value; $DPPropsValue1[$_.PropertyName] = $_.Value1 }

	Write-HTMLHeading -Text "$CMDPServerFQDN" -Level 3 -File $FilePath
	Write-HTMLParagraph -Text "Description: $($DPPropsValue1['Description'])" -Level 4 -File $FilePath


	Write-Verbose "Trying to ping $CMDPServerFQDN"
	$PingResult = Ping-Host $CMDPServerFQDN
	If (-not($PingResult)) {
		Write-Debug "Ping Failed: $CMDPServerFQDN"
		Write-HTMLParagraph -Text "The Distribution Point $CMDPServerFQDN is not pingable. Check connectivity." -Level 3 -File $FilePath
	}
	Write-Debug "Ping Succeeded: $CMDPServerFQDN"


	#Get DP drive info.  Use real-time remote WMI/WinRM information if SkipRemoteServerDetails is not specified
	Write-HTMLParagraph -Text '<B>Disk Information:</B>' -Level 4 -File $FilePath
	If ($PSBoundParameters.ContainsKey('SkipRemoteServerDetails')) {
		#Get monitoring info from ConfigMgr database
		$CMDPDrives = @(Get-CIMInstance @WMIsplat -ClassName SMS_DistributionPointDriveInfo -Filter "NALPath like '%\\$CMDPServerFQDN\\'")
		$DPDrives = $null; $DPDrives += ForEach ($CMDPDrive in $CMDPDrives) {
			$Size = 0; $Size = $CMDPDrive.BytesTotal / 1024 / 1024
			$Freesize = 0; $Freesize = $CMDPDrive.BytesFree / 1024 / 1024
			#String NALPath;
			#SInt32 ConttentLibPriority;
			#SInt32 ObjectType;
			#SInt32 PkgSharePriority;
			#SInt32 Status;
			New-Object -TypeName psobject -Property @{'Partition' = "$($CMDPDrive.Drive):"; 'Size' = "$($Size.ToString('N0')) GB"; 'Free Space' = "$($FreeSize.ToString('N2')) GB"; 'Percent Free' = "$($CMDPDrive.PercentFree)%" }
		}
	} Else {
		#Get real-time info from remote server
		$CMDPDrives = @(Get-WmiObject -ComputerName $CMDPServerFQDN -Namespace 'root\CIMv2' -Class 'Win32_LogicalDisk' -Filter "DriveType = '3'")
		$DPDrives = $null; $DPDrives += ForEach ($CMDPDrive in $CMDPDrives) {
			$Size = 0; $Size = $CMDPDrive.Size / 1024 / 1024
			$Freesize = 0; $Freesize = $CMDPDrive.FreeSpace / 1024 / 1024
			New-Object -TypeName psobject -Property @{'Partition' = "$($CMDPDrive.DeviceID)"; 'Size' = "$($Size.ToString('N0')) GB"; 'Free Space' = "$($FreeSize.ToString('N2')) GB"; 'Percent Free' = ($CMDPDrive.FreeSpace / $CMDPDrive.Size).ToString('P') }
		}
		#TODO: Get Windows Server data deduplication configuration per drive #https://powershell.org/forums/topic/how-to-capture-all-output-from-invoke-command/
		$DPDrivesDedup = @(Invoke-Command -ComputerName $CMDPServerFQDN -ScriptBlock { & { Import-Module Deduplication; Get-DedupVolume 4>&1 }})
	}
	$DPDrives = $DPDrives | Select-Object 'Partition', 'Size', 'Free Space', 'Percent Free'
	Write-HtmlTable -InputObject $DPDrives -Border 1 -Level 4 -File $FilePath
	If ($DPDrivesDedup) {
		Write-HTMLParagraph -Text '<B>Disk Deduplication Information:</B>' -Level 4 -File $FilePath
        $DPDrivesDedup = $DPDrivesDedup | Select-Object Volume, Enabled, MinimumFileAgeDays,  @{N='SavingsRate'; E= { ($_.SavingsRate/100).ToString('P') }}, @{N='Saved GB'; E= { ($_.SavedSpace/1024/1024/1024).ToString('N2') }}, @{N='Used GB'; E= { ($_.UsedSpace/1024/1024/1024).ToString('N2') }}, @{N='Unoptimized GB'; E= { ($_.UnoptimizedSize/1024/1024/1024).ToString('N2') }} #MinimumFileSize, NoCompress, OptimizeInUseFiles,
		Write-HtmlTable -InputObject $DPDrivesDedup -Border 1 -Level 4 -File $FilePath
	}


	#Get hardware info.  Use real-time remote WMI/WinRM information if SkipRemoteServerDetails is not specified
	Write-HTMLParagraph -Text '<B>Hardware Information:</B>' -Level 4 -File $FilePath
	If ($PSBoundParameters.ContainsKey('SkipRemoteServerDetails') -or $PingResult -eq $false) {
		#Get client inventory info from ConfigMgr database
		$ResourceID = (Get-WmiObject @WMIsplat -Class SMS_R_System -Filter "Name = '$CMDPServerName' and FullDomainName = '$CMDPServerDomainName'").ResourceId
		If ([int]$ResourceID -is [int]) {
			$CPUs = @(Get-WmiObject @WMIsplat -Class SMS_G_System_PROCESSOR -Filter "ResourceID = '$ResourceID'" -Property NumberOfCores, NumberOfLogicalProcessors, Name)
			ForEach ($CPU in $CPUs) { $Cores += $CPU.NumberOfCores }
			[int]$MemoryMB = 0; (Get-WmiObject @WMIsplat -Class SMS_G_System_PHYSICAL_MEMORY -Filter "ResourceID = '$ResourceID'" -Property Capacity) | ForEach-Object { [int]$MemoryMB += [int]$_.Capacity }
			If ($CPUs -or $MemoryMB -gt 0) {
				$DPText += "<BR /><UL><LI>$($CPU.Name)</LI><LI>$Cores Cores</LI><LI>$([System.Math]::Round($MemoryMB/1024,2)) GB RAM</LI></UL>"
			}
		} Else {
			$DPText += "<BR />Failed to query inventory for server $CMDPServerFQDN<BR /><BR />"
		}
	} Else {
		#Get real-time info from remote server
		try {
			$Memory = 0
			Get-WmiObject -Class Win32_PhysicalMemory -ComputerName $CMDPServerFQDN | ForEach-Object { [int64]$Memory += [int64]$_.Capacity }
			$MemoryGB = $Memory / 1024 / 1024 / 1024
			$CPUs = Get-WmiObject -Class win32_processor -ComputerName $CMDPServerFQDN
			$CPUModel = $CPU.Name
			$Cores = 0; ForEach ($CPU in $CPUs) { $Cores = $Cores + $CPU.NumberOfCores }
			$DPText += "<BR /><UL><LI>$CPUModel</LI><LI>$Cores Cores</LI><LI>$($MemoryGB) GB RAM</LI></UL>"
		} catch {
			$DPText += "<BR />Failed to access server $CMDPServerFQDN<BR /><BR />"
		}
	}
	Write-HtmlTable -InputObject $DPText -Border 1 -Level 4 -File $FilePath


	$DPText = "<B>Additional Configuration:</B><ul>"
    #TODO: review SMS_DistributionPointInfo class for additional properties
    #TODO: review SMS_SCI_SysResUse class for additional properties
	#Build a hashtable for each value pair of DP props for both "Value/Value0" and "Value1" where info is actually stored.  This method is much faster than multiple where clauses
	$DPPropsTable = @{}
	$DPPropsTable['Active Directory Site Name'] = $DPPropsValue1['ADSiteName']
	$DPPropsTable['Is Pull Distribution Point'] = [bool]$DPPropsValue0['IsPullDP']
	$DPPropsTable['PreStaged Content enabled'] = [bool]$DPPropsValue0['PreStagingAllowed']
	$DPPropsTable['HTTPS/SSL enabled'] = [bool]$DPPropsValue0['SslState']
	$DPPropsTable['Internet Client connections enabled'] = [bool]$DPPropsValue0['AllowInternetClients']
	$DPPropsTable['Anonymous connections enabled'] = [bool]$DPPropsValue0['IsAnonymousEnabled']
	$DPPropsTable['DPDrive'] = $DPPropsValue1['DPDrive']
	$DPPropsTable['Reserved Disk Space'] = [string]$DPPropsValue0['MinFreeSpace'] + ' MB'
	$DPPropsTable['Multicast enabled'] = [bool]$DPPropsValue0['IsMulticast']
	$DPPropsTable['PXE is enabled'] = [bool]$DPPropsValue0['IsPXE']
	If ($DPPropsTable['PXE is enabled'] -eq $true) {
		$DPPropsTable['PXE Unknown Machine support'] = [bool]$DPPropsValue0['SupportUnknownMachines']
		$DPPropsTable['PXE password enabled'] = [bool]$DPPropsValue0['PXEPassword']
		$DPPropsTable['PXE uses CM PXE point'] = [bool]$DPPropsValue0['SccmPXE']
	}
	#TODO: convert to DateTime
	$DPPropsTable['Certificate expiration date'] = $DPPropsValue1['CertificateExpirationDate']
	#If ($DPPropsTable['Certificate expiration date'] -lt Get-Date) { $DPPropsTable['Certificate expiration date'] = [string]$DPPropsTable['Certificate expiration date'] + ' ERROR!  Certificate is expired'}
	#If ($DPPropsTable['Certificate expiration date'] -lt (Get-Date).AddDays(60)) { $DPPropsTable['Certificate expiration date'] = [string]$DPPropsTable['Certificate expiration date'] + ' WARNING!  Certificate expires soon'}
	$DPPropsTable['Available ContentLib Drives'] = $DPPropsValue1['AvailableContentLibDrivesList']
	$DPPropsTable['Available PkgShare Drives'] = $DPPropsValue1['AvailablePkgShareDrivesList']
	$DPPropsTable['Version'] = $DPPropsValue1['Version']
	$DPPropsTable['IPv4 Subnets'] = $DPPropsValue1['IPSubnets']
	$DPPropsTable['LEDBAT enabled'] = [bool]$DPPropsValue0['LEDBATEnabled']
	$DPPropsTable['Distribute content on demand'] = [bool]$DPPropsValue0['DistributeOnDemand']
	#TODO: $DPPropsTable[''] = [bool]$DPPropsValue0['IsActive']
	#TODO: $DPPropsTable[''] = [bool]$DPPropsValue0['UdaSetting']
	#TODO: $DPPropsTable[''] = [bool]$DPPropsValue0['CertificateType']
	#TODO: $DPPropsTable[''] = [bool]$DPPropsValue0['TransferRate']
	#TODO: $DPPropsTable[''] = $DPPropsValue1['DPMonSchedule']
	#Debug: List properties have not been accounted for
	#ForEach ($Prop in $DPResources.props) { If ($null -eq $DPPropsTable[$Prop.PropertyName]) { $Prop | Select-Object PropertyName, Value, Value1}}
	ForEach ($Prop in $DPPropsTable.GetEnumerator()) {
		$DPText += '<LI>' + $Prop.Name + ': ' + $Prop.Value + '</LI>'
	}
	$DPText += '</ul>'
	#TODO: convert to Write-HTMLTable
	Write-HTMLParagraph -Text $DPText -Level 4 -File $FilePath


	#Get DP Group membership
	$DPText = '<B>Distribution Point Group Membership:</B><UL>'
	$DPGroupMembers = @(Get-CimInstance @WMIsplat -ClassName SMS_DPGroupMembers -Filter "DPNALPath like '%\\$CMDPServerFQDN\\'" | Select-Object GroupId)
	If ($DPGroupMembers.Count -gt 0) {
        $DPGroups = @{}; (Get-CimInstance @WMIsplat -ClassName SMS_DistributionPointGroup) | ForEach-Object { $DPGroups[$_.GroupID] = $_.Name } #Description
		Foreach ($DPGroup in $DPGroupMembers) {
			$DPText += "<LI>$($DPGroups[$DPGroup.GroupID])</LI>"
		}
		$DPText += '</ul>'
	} Else {
		$DPText += '<li>This Distribution Point is not a member of any DP Group.</li></ul>'
	}
	#TODO: convert to Write-HTMLTable
	Write-HTMLParagraph -Text $DPText -Level 4 -File $FilePath

	<#Distribution Point wmi classes https://docs.microsoft.com/en-us/mem/configmgr/develop/reference/core/servers/configure/sms_distributionpointinfo-server-wmi-class
	SMS_DistributionPoint
      UInt32 ISVDataSize;
      String ISVString;
      DateTime LastRefreshTime;
      UInt32 ObjectTypeID;
      String PackageID;
      UInt32 PackageType;
      String ResourceType;
      String SecureObjectID;
      String ServerNALPath;
      String SiteCode;
      String SiteName;
      String SourceSite;
      UInt32 Status;
	SMS_DistributionDPStatus
	#>
}

Function Write-ProgressEx ($Activity, $Stutus, $CurrentOperation) { Write-Output $CurrentOperation }
Function Write-HTMLHeading ($Text, $Level, [switch]$Pagebreak, $File) { Write-Output $Text }
Function Write-HTMLParagraph ($Text, $Level, [switch]$Pagebreak, $File) { Write-Output $Text }
Function Write-HtmlTable ($InputObject, $Border, $Level, $File) { Write-Output $InputObject }
$CMSite = Get-CMSite
$SieCode = $CMSite.SiteCode
$SiteServer = $CMSite.ServerName
$SMSProvider = $CMSite.ServerName
$FilePath = 'C:\CMDocumentation.html'

#region Distribution Point details
Write-ProgressEx -CurrentOperation "Distribution Point(s) Summary"
Write-HTMLHeading -Text "Summary of Distribution Points for Site $($CMSite.SiteCode)" -Level 2 -PageBreak -File $FilePath
#TODO: convert to WMI query
$CMDistributionPoints = Get-CMDistributionPoint -SiteCode $CMSite.SiteCode
#$CMDistributionPoints = Get-WmiObject -ComputerName $SiteServer -Namespace "root\SMS\site_$($CMSite.SiteCode)" -Class SMS_DistributionPointInfo
    foreach ($CMDistributionPoint in $CMDistributionPoints) {
        $CMDPServerName = $CMDistributionPoint.NetworkOSPath.Split('\\')[2]
        If ($PSBoundParameters.ContainsKey('SkipRemoteServerDetails')) {
            Get-pwDistributionPointDetails -ServerName $CMDPServerName -SiteCode $CMSite.SiteCode -SMSProvider $SMSProvider -SkipRemoteServerDetails -File $FilePath
        } Else {
            Get-pwDistributionPointDetails -ServerName $CMDPServerName -SiteCode $CMSite.SiteCode -SMSProvider $SMSProvider -File $FilePath
        }
    }
