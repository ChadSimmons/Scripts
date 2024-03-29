﻿<#
.SYNOPSIS
    ConfigMgr Client Health is a tool that validates and automatically fixes errors on Windows computers managed by Microsoft Configuration Manager.    
.EXAMPLE 
   .\ConfigMgr-ClientHealth.ps1 -Config .\Config.Xml
.EXAMPLE 
    \\sccm.lab.net\ClientHealth$\ConfigMgr-ClientHealth.ps1 -Config \\sccm.lab.net\ClientHealth$\Config.Xml
.PARAMETER Config
    A single parameter specifying the path to the configuration XML file.
.DESCRIPTION
    ConfigMgr Client Health detects and fixes following errors:
        * ConfigMgr client is not installed.
        * ConfigMgr client is assigned the correct site code.
        * ConfigMgr client is upgraded to current version if not at specified minimum version.
        * ConfigMgr client not able to forward state messages to management point.
        * ConfigMgr client stuck in provisioning mode.
        * ConfigMgr client maximum log file size.
        * ConfigMgr client cache size.
        * Corrupt WMI.
        * Services for ConfigMgr client is not running or disabled.
        * Other services can be specified to start and run and specific state.
        * Hardware inventory is running at correct schedule
        * Group Policy is updating registry.pol
        * ConfigMgr Client Update Handler is working correctly with registry.pol
        * Windows Update Agent not working correctly, causing client not to receive patches.
        * Windows Update Agent missing patches that fixes known bugs.
.NOTES 
    You should run this with at least local administrator rights. It is recommended to run this script under the SYSTEM context.
    
    DO NOT GIVE USERS WRITE ACCESS TO THIS FILE. LOCK IT DOWN !
    
    Author: Anders Rødland
    Blog: https://www.andersrodland.com
    Twitter: @AndersRodland
.LINK
    Full documentation: https://www.andersrodland.com/configmgr-client-health/
#> 
[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact="Medium")]

param(
    [Parameter(Mandatory=$True, HelpMessage='Path to XML Configuration File')]
    [ValidateScript({Test-Path -Path $_ -PathType Leaf})]
    [ValidatePattern('.xml$')]
    [string]$Config
    )

Begin {
    # ConfigMgr Client Health Version
    $Version = '0.6.5'
    $PowerShellVersion = [int]$PSVersionTable.PSVersion.Major
    
    # Read configuration from XML file
    if (Test-Path $Config) {
        Try {
            $Xml = [xml](Get-Content -Path $Config)
        } Catch {
            $ErrorMessage = $_.Exception.Message
            $text = "Error, could not read $Config. Check file location and share/ntfs permissions. Is XML config file damaged?"
            $text += "`nError message: $ErrorMessage"
            Write-Error $text
            Exit 1
        }
    }
    else {
        $text = "Error, could not access $Config. Check file location and share/ntfs permissions. Did you misspell the name?"
        Write-Error $text
        Exit 1
    }

    #region functions
    Function Get-DateTime {
        $obj = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        Write-Output $obj
    }

    Function Get-LogFileName {
        #$OS = Get-WmiObject -class Win32_OperatingSystem
        $OSName = Get-OperatingSystem
        $logshare = Get-XMLConfigLoggingShare
        $obj = "$logshare\$OSName\$env:computername.log"
        Write-Output $obj
    }

    Function Out-LogFile {
        Param([Parameter(Mandatory=$false)][xml]$Xml, $Text)
        $logFile = Get-LogFileName
        $obj = '[' +(Get-DateTime) +'] '+$text
        $obj | Out-File -Encoding ascii -Append $logFile
    }

    Function Get-OperatingSystem {
        $OS = Get-WmiObject -class Win32_OperatingSystem
        
        # Handles different OS languages
        $OSArchitecture = ($OS.OSArchitecture -replace ('([^0-9])(\.*)', '')) + '-Bit'
        switch -Wildcard ($OS.Caption) {
            "*Windows 7*" {$OSName = "Windows 7 " + $OSArchitecture}
            "*Windows 8.1*" {$OSName = "Windows 8.1 " + $OSArchitecture}
            "*Windows 10*" {$OSName = "Windows 10 " + $OSArchitecture}
            "*Server 2008*" {
                if ($OS.Caption -like "*R2*") {
                    $OSName = "Windows Server 2008 R2 " + $OSArchitecture
                }
                else {
                    $OSName = "Windows Server 2008 " + $OSArchitecture
                }
            }
            "*Server 2012*" {
                if ($OS.Caption -like "*R2*") {
                    $OSName = "Windows Server 2012 R2 " + $OSArchitecture
                }
                else {
                    $OSName = "Windows Server 2012 " + $OSArchitecture
                }
            }
            "*Server 2016*" {
                $OSName = "Windows Server 2016 " + $OSArchitecture
            }
        }
        Write-Output $OSName
    }

    Function Get-MissingUpdates {
        $UpdateShare = Get-XMLConfigUpdatesShare
        $OSName = Get-OperatingSystem

        $build = $null
        if ($OSName -like "*Windows 10*") {
            $build = Get-WmiObject Win32_OperatingSystem | Select-Object -ExpandProperty BuildNumber
            switch ($build) {
                10586 {$OSName = $OSName + " 1511"}
                14393 {$OSName = $OSName + " 1607"}
                15063 {$OSName = $OSName + " 1703"}
                default {$OSName = $OSName + " Insider Preview"}
            }
        }

        $Updates = $UpdateShare + "\" + $OSName + "\"
        $obj = New-Object PSObject @{}
        If ((Test-Path $Updates) -eq $true) {
            $regex = "\b(?!(KB)+(\d+)\b)\w+"
            $hotfixes = (Get-ChildItem $Updates | Select-Object -ExpandProperty Name)
            $installedUpdates = Get-Hotfix | Select-Object -ExpandProperty HotFixID

            foreach ($hotfix in $hotfixes) {
                $kb = $hotfix -replace $regex -replace "\." -replace "-"
                if ($installedUpdates -like $kb) {}
                else {
                    $obj.Add('Hotfix', $hotfix)
                }
            }
        }
        Write-Output $obj
    }

    Function Get-Sitecode {
        try {
            $obj = $([WmiClass]"ROOT\ccm:SMS_Client").getassignedsite() | Select-Object -Expandproperty sSiteCode
        } catch {
            $obj = $false
        } finally {
            Write-Output $obj
        }
    }

    Function Get-ClientVersion {
        try {
            $obj = (Get-WmiObject -Namespace root/ccm SMS_Client).ClientVersion
        } catch {
            $obj = $false
        } finally {
            Write-Output $obj
        }
    }

    Function Get-ClientCache {
        try {
            $obj = (Get-WmiObject -Namespace "ROOT\CCM\SoftMgmtAgent" -Class CacheConfig).Size
        } catch {
            $obj = $false
        } finally {
            Write-Output $obj
        }
    }

    Function Get-ClientMaxLogSize {
        try {
            $obj = ((Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\CCM\Logging\@Global').LogMaxSize) / 1000
        } catch {
            $obj = $false
        } finally {
            if ($obj -eq 0) {
                $obj = $false
            }
            Write-Output $obj
        }
    }

    Function Get-ClientMaxLogHistory {
        try {
            $obj = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\CCM\Logging\@Global').LogMaxHistory
        } catch {
            $obj = $false
        } finally {
            if ($null -eq $obj) {
                $obj = $false
            }
            Write-Output $obj
        }
    }


    Function Get-Domain {
        try {
            $obj = (Get-WmiObject Win32_ComputerSystem).Domain
        } catch {
            $obj = $false
        } finally {
            Write-Output $obj
        }
    }

    function Test-CCMCertificateError {
        # More checks to come
        $logFile1 = 'c:\windows\ccm\logs\ClientIDManagerStartup.log'
        $error1 = 'Failed to find the certificate in the store'
        $error2 = '[RegTask] - Server rejected registration 3'
        $content = Get-Content -Path $logFile1

        $ok = $true

        if ($content -match $error1) {
            $ok = $false
            $text = 'ConfigMgr Client Certificate: Error failed to find the certificate in store. Attempting fix.'
            Write-Warning $text
            Stop-Service -Name ccmexec -Force
            # Name is persistant across systems.
            $cert = 'C:\ProgramData\Microsoft\Crypto\RSA\MachineKeys\19c5cf9c7b5dc9de3e548adb70398402_50e417e0-e461-474b-96e2-077b80325612'
            Remove-Item -Path $cert -Force -ErrorAction SilentlyContinue | Out-Null
            # CCM create new certificate when missing.
            Start-Service -Name ccmexec
            # Delete the log file to avoid triggering this check again when it's fixed.
            Remove-Item $logFile -Force -ErrorAction SilentlyContinue | Out-Null
            
            # Update log object
            $log.Certificate = $error1
        }

        #$content = Get-Content -Path $logFile2
        if ($content -match $error2) {
            $ok = $false
            $text = 'ConfigMgr Client Certificate: Error! Server rejected client registration. Client Certificate not valid. No auto-remediation.'
            Write-Error $text
            $log.Certificate = $error2
        }

        if ($ok = $true) {
            $text = 'ConfigMgr Client Certificate: OK'
            Write-Output $text
            $log.Certificate = 'OK'
        }
        #Out-LogFile -Xml $Xml -Text $text
    }

    function Get-PendingReboot {
        $result = @{
            CBSRebootPending =$false
            WindowsUpdateRebootRequired = $false
            FileRenamePending = $false
            SCCMRebootPending = $false
        }

        #Check CBS Registry
        $key = Get-ChildItem "HKLM:Software\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending" -ErrorAction SilentlyContinue
        if ($null -ne $key) 
        {
            $result.CBSRebootPending = $true
        }
    
        #Check Windows Update
        $key = Get-Item 'HKLM:SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired' -ErrorAction SilentlyContinue
        if ($null -ne $key) 
        {
            $result.WindowsUpdateRebootRequired = $true
        }

        #Check PendingFileRenameOperations
        $prop = Get-ItemProperty 'HKLM:SYSTEM\CurrentControlSet\Control\Session Manager' -Name PendingFileRenameOperations -ErrorAction SilentlyContinue
        if ($null -ne $prop) 
        {
            #PendingFileRenameOperations is not *must* to reboot?
            #$result.FileRenamePending = $true
        }
        
        try 
        { 
            $util = [wmiclass]'\\.\root\ccm\clientsdk:CCM_ClientUtilities'
            $status = $util.DetermineIfRebootPending()
            if(($null -ne $status) -and $status.RebootPending){
                $result.SCCMRebootPending = $true
            }
        }catch{}

        #Return Reboot required
        if ($result.ContainsValue($true)) {
            #$text = 'Pending Reboot: YES'
            $obj = $true
            $log.PendingReboot = 'Pending Reboot'
        }
        else {
            $obj = $false
            $log.PendingReboot = 'OK'
        }
        Write-Output $obj
    }

    Function Get-ProvisioningMode {
        $registryPath = 'HKLM:\SOFTWARE\Microsoft\CCM\CcmExec'
        $provisioningMode = (Get-ItemProperty -Path $registryPath).ProvisioningMode

        if ($provisioningMode -eq 'true') {
            $obj = $true
        }
        else {
            $obj = $false
        }
        Write-Output $obj
    }

    Function Get-OSDiskFreeSpace {
        $driveC = Get-WmiObject -Class Win32_LogicalDisk | Where-Object {$_.DeviceID -eq 'C:'} | Select-Object FreeSpace, Size
        $freeSpace = (($driveC.FreeSpace / $driveC.Size) * 100)
        Write-Output ([math]::Round($freeSpace,2))
    }

    Function Get-Computername {
        $obj = (Get-WmiObject Win32_ComputerSystem).Name
        Write-Output $obj
    }

    Function Get-LastBootTime {
        $wmi = Get-WmiObject Win32_OperatingSystem
        $obj = $wmi.ConvertToDateTime($wmi.LastBootUpTime)
        Write-Output $obj
    }

    Function Get-LastInstalledPatches {
        Param([Parameter(Mandatory=$true)]$Log)
        # Reading date from Windows Update COM object.
        $Session = New-Object -ComObject Microsoft.Update.Session
        $Searcher = $Session.CreateUpdateSearcher()
        $HistoryCount = $Searcher.GetTotalHistoryCount()
        
        $OS = Get-OperatingSystem
        Switch -Wildcard ($OS) {
            "*Windows 7*" { $Date = $Searcher.QueryHistory(0,$HistoryCount) | Where-Object {$_.ClientApplicationID -eq 'AutomaticUpdates'} | Select-Object -ExpandProperty Date | Measure-Latest }
            "*Windows 8*" { $Date = $Searcher.QueryHistory(0,$HistoryCount) | Where-Object ClientApplicationID -eq AutomaticUpdatesWuApp | Select-Object -ExpandProperty Date | Measure-Latest }
            "*Windows 10*" { $Date = $Searcher.QueryHistory(0,$HistoryCount) | Where-Object {$_.ClientApplicationID -eq 'UpdateOrchestrator'} | Select-Object -ExpandProperty Date | Measure-Latest }
            "*Server 2008*" { $Date = $Searcher.QueryHistory(0,$HistoryCount) | Where-Object {$_.ClientApplicationID -eq 'AutomaticUpdates'} | Select-Object -ExpandProperty Date | Measure-Latest }
            "*Server 2012*" { $Date = $Searcher.QueryHistory(0,$HistoryCount) | Where-Object ClientApplicationID -eq AutomaticUpdatesWuApp | Select-Object -ExpandProperty Date | Measure-Latest }
            "*Server 2016*" { $Date = $Searcher.QueryHistory(0,$HistoryCount) | Where-Object {$_.ClientApplicationID -eq 'UpdateOrchestrator'} | Select-Object -ExpandProperty Date | Measure-Latest }
        }

        # Reading date from PowerShell Get-Hotfix
        #$now = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        #$Hotfix = Get-Hotfix | Where-Object {$_.InstalledOn -le $now} | Select-Object -ExpandProperty InstalledOn -ErrorAction SilentlyContinue
        $Hotfix = Get-Hotfix | Select-Object -ExpandProperty InstalledOn -ErrorAction SilentlyContinue
        $Date2 = $null
        
        if ($null -ne $hotfix) {
            $Date2 = Get-Date($hotfix | Measure-Latest) -ErrorAction SilentlyContinue
        }

        if (($Date -ge $Date2) -and ($null -ne $Date)) {
            $Log.OSUpdates = Get-SmallDateTime -Date $Date
        }
        elseif (($Date2 -gt $Date) -and ($null -ne $Date2)) {
            $Log.OSUpdates = Get-SmallDateTime -Date $Date2
        }
    }

    function Measure-Latest {
        BEGIN { $latest = $null }
        PROCESS {
                if (($null -ne $_) -and (($null -eq $latest) -or ($_ -gt $latest))) {
                    $latest = $_ 
                }
        }
        END { $latest }
    }

    Function Test-LogFileHistory {
        $startString = '<--- ConfigMgr Client Health Check starting --->'
        $stopString = '<--- ConfigMgr Client Health Check finished --->'
        $logfile = Get-LogFileName
        $content = ''
        if (Test-Path $logfile -ErrorAction SilentlyContinue)  {
            $content = Get-Content($logfile)
        }
        $maxHistory = Get-XMLConfigLoggingMaxHistory
        $startCount = [regex]::matches($content,$startString).count
        $stopCount = [regex]::matches($content,$stopString).count
        
        # Delete logfile if more start and stop entries than max history
        if (($startCount -ge $maxHistory) -and ($stopCount -ge $maxHistory)) {
            if ((Test-Path -Path $logfile -ErrorAction SilentlyContinue) -eq $true) {
                Remove-Item $logfile -Force
            }
        }
    }

    Function Test-DNSConfiguration {
        Param([Parameter(Mandatory=$true)]$Log)
        $comp = Get-WmiObject Win32_ComputerSystem
        $fqdn = $comp.Name + '.'+$comp.Domain
        $localIPs = Get-WmiObject Win32_NetworkAdapterConfiguration | Where-Object {$_.IPEnabled -Match "True"} |  Select-Object -ExpandProperty IPAddress
        $dnscheck = [System.Net.DNS]::GetHostByName($fqdn)
        $dnsAddressList = $dnscheck.AddressList | Select-Object -ExpandProperty IPAddressToString
        $dnsFail = ''
        $logFail = ''

        Write-Verbose 'Verify that local machines FQDN matches DNS'
        if ($dnscheck.HostName -like $fqdn) {
            $obj = $true
            Write-Verbose 'Checking if one local IP matches on IP from DNS'
            Write-Verbose 'Loop through each IP address published in DNS'
            foreach ($dnsIP in $dnsAddressList) {
                Write-Verbose 'Testing if IP address published in DNS exist in local IP configuration.'
                ##if ($dnsIP -notin $localIPs) { ## Requires PowerShell 3. Works fine :(
                if ($localIPs -notcontains $dnsIP) {
                   $dnsFail += "IP $dnsIP in DNS record do not exist`n"
                   $logFail += "$dnsIP "
                   $obj = $false
                }
            }
        }
        else {
            $dnsFail = 'DNS name: ' +$dnscheck.HostName + ' local fqdn: ' +$fqdn + ' DNS IPs: ' +$dnsAddressList + ' Local IPs: ' + $localIPs
            $obj = $false
        }

        switch ($obj) {
            $false {
                $text = 'DNS Check: FAILED. IP address published in DNS do not match IP address on local machine. Trying to resolve by registerting with DNS server'
                if ($PowerShellVersion -ge 4) {
                    Register-DnsClient | out-null
                }
                else {
                    ipconfig /registerdns | out-null
                }
                Write-Warning $text
                $log.DNS = $logFail
                Out-LogFile -Xml $xml -Text $text
                Out-LogFile -Xml $xml -Text $dnsFail
            }
            $true {
                $text = 'DNS Check: OK'
                Write-Output $text
                $log.DNS = 'OK'
                #Out-LogFile -Xml $xml -Text $text
            }
        }
        #Write-Output $obj
    }

    Function Test-Update {
        Param([Parameter(Mandatory=$true)]$Log)
        Write-Verbose 'Only run update check if enabled'
        if (($Xml.Configuration.Option | Where-Object {$_.Name -like 'Updates'} | Select-Object -ExpandProperty 'Enable') -like 'True') {
            
            $UpdateShare = $Xml.Configuration.Option | Where-Object {$_.Name -like 'Updates'} | Select-Object -ExpandProperty 'Share'
            Write-Verbose "Validating required updates is installed on the client. Required updates will be installed if missing on client."
            #$OS = Get-WmiObject -class Win32_OperatingSystem
            $OSName = Get-OperatingSystem

            $build = $null
            if ($OSName -like "*Windows 10*") {
                $build = Get-WmiObject Win32_OperatingSystem | Select-Object -ExpandProperty BuildNumber
                switch ($build) {
                    10586 {$OSName = $OSName + " 1511"}
                    14393 {$OSName = $OSName + " 1607"}
                    15063 {$OSName = $OSName + " 1703"}
                    default {$OSName = $OSName + " Insider Preview"}
                }
            }

            $Updates = $UpdateShare + "\" + $OSName + "\"
            If ((Test-Path $Updates) -eq $true) {
                $regex = "\b(?!(KB)+(\d+)\b)\w+"
                $hotfixes = (Get-ChildItem $Updates | Select-Object -ExpandProperty Name)
                $installedUpdates = Get-Hotfix | Select-Object -ExpandProperty HotFixID

                if ($hotfixes.count -eq 0) {
                    $text = 'Updates: No mandatory updates to install.'
                    Write-Output $text
                    $log.Updates = 'OK'
                }

                $logEntry = $null
                    
                foreach ($hotfix in $hotfixes) {
                    $kb = $hotfix -replace $regex -replace "\." -replace "-"
                    if ($installedUpdates -like $kb) {
                        $text = "Update $hotfix" + ": OK"
                        Write-Output $text
                    }
                    else {
                        $kbfullpath = $updates + "$hotfix"
                        $text = "Update $hotfix" + ": Missing. Installing now..."
                        Write-Warning $text
            
                        If ((Test-Path c:\temp\clienthealth) -eq $false) {
                            New-Item -Path C:\Temp\ClientHealth -ItemType Directory | Out-Null
                        }

                        if ($null -eq $logEntry) {
                            $logEntry = $kb
                        }
                        else {
                            $logEntry += ", $kb"
                        }
            
                        Copy-Item -Path $kbfullpath -Destination c:\temp\clienthealth
                        $install = "c:\temp\clienthealth\" +$hotfix
            
                        wusa.exe $install /quiet /norestart
                        While (Get-Process wusa -ErrorAction SilentlyContinue) {
                            Start-Sleep 3
                        }
                        Remove-Item $install -force
                    }
                    #Out-LogFile -Xml $xml -Text $text

                    if ($null -eq $logEntry) {
                        $log.Updates = 'OK'
                    }
                    else {
                        $log.Updates = $logEntry
                    }
                }
            }
        }
    }

    Function Test-ConfigMgrClient {
        if (Get-Service -Name ccmexec -ErrorAction SilentlyContinue) {
            $text = "Configuration Manager Client is installed"
            Write-Output $text
        }
        else {
            $text = "Configuration Manager client is not installed. Installing and sleeping for 10 minutes for it to configure..."
            Write-Warning $text
            #$newinstall = $true
            Resolve-Client -Xml $xml -ClientInstallProperties $clientInstallProperties -FirstInstall $true
            Start-Sleep 600
        }
        #Out-LogFile -Xml $xml -Text $text
    }

    Function Test-ClientCacheSize {
        $ClientCacheSize = Get-XMLConfigClientCache
        $Cache = Get-WmiObject -Namespace "ROOT\CCM\SoftMgmtAgent" -Class CacheConfig
        $CurrentCache = Get-ClientCache

        if ($ClientCacheSize -match '%') {
            $type = 'percentage'
            # percentage based cache based on disk space
            $num = $ClientCacheSize -replace '%'
            $num = ($num / 100)
            # TotalDiskSpace in Byte
            $TotalDiskSpace = (Get-WmiObject -Class Win32_LogicalDisk | Where-Object {$_.DeviceID -eq 'C:'} | Select-Object -ExpandProperty Size)
            $ClientCacheSize = ([math]::Round(($TotalDiskSpace * $num) / 1048576))
        }
        else {
            $type = 'fixed'
        }

        if ($CurrentCache -eq $ClientCacheSize) {
            $text = "ConfigMgr Client Cache Size: OK"
            Write-Host $text
            $obj = $false
        }

        else {
            switch ($type) {
                'fixed' {$text = "ConfigMgr Client Cache Size: $CurrentCache. Expected: $ClientCacheSize. Redmediating and tagging CcmExec Service for restart..."}
                'percentage' {
                    $percent = Get-XMLConfigClientCache
                    $text = "ConfigMgr Client Cache Size: $CurrentCache. Expected: $ClientCacheSize ($percent). Redmediating and tagging CcmExec Service for restart..."
                }
            }
            
            Write-Warning $text
            $Cache.Size = $ClientCacheSize
            $Cache.Put()
            $obj = $true
        }
        #Out-LogFile -Xml $xml -Text $text
        Write-Output $obj
    }

    Function Test-ClientVersion {
        Param([Parameter(Mandatory=$true)]$Log)
        $ClientVersion = Get-XMLConfigClientVersion
        $installedVersion = Get-ClientVersion
        $log.ClientVersion = $installedVersion

        if ($installedVersion -ge $ClientVersion) {
            $text = 'ConfigMgr Client version is: ' +$installedVersion + ': OK'
            Write-Output $text
            $obj = $false
        }
        elseif ( (Get-XMLConfigClientAutoUpgrade).ToLower() -like 'true' ) {
            $text = 'ConfigMgr Client version is: ' +$installedVersion +': Tagging client for upgrade to version: '+$ClientVersion
            Write-Warning $text
            $obj = $true
        }
        else {
            $text = 'ConfigMgr Client version is: ' +$installedVersion +': Required version: '+$ClientVersion +' AutoUpgrade: false. Skipping upgrade'
            Write-Output $text
            $obj = $false
        }
        #Out-LogFile -Xml $xml -Text $text
        Write-Output $obj
    }

    Function Test-ClientSiteCode {
        $ClientSiteCode = Get-XMLConfigClientSitecode
        $currentSiteCode = Get-Sitecode

        # As of ConfigMgr 1610, WMI Method SetAssignedSite do not work. Test again in next stable release. Avoid reinstall of client if possible.
        if ($ClientSiteCode -like $currentSiteCode) {
            $text = "ConfigMgr Client Site Code: OK"
            Write-Host $text
            $obj = $false
        }
        else {
            $text = 'ConfigMgr Client Site Code is ' +$currentSiteCode + ": Expected: $ClientSiteCode. Tagging client for reinstall"
            Write-Warning $text
            $obj = $true
        }
        #Out-LogFile -Xml $xml -Text $text
        Write-Output $obj
    }

    function Test-PendingReboot {
        Param([Parameter(Mandatory=$true)]$Log)
        # Only run pending reboot check if enabled in config
        if (($Xml.Configuration.Option | Where-Object {$_.Name -like 'PendingReboot'} | Select-Object -ExpandProperty 'Enable') -like 'True') {
            $result = @{
                CBSRebootPending =$false
                WindowsUpdateRebootRequired = $false
                FileRenamePending = $false
                SCCMRebootPending = $false
            }

            #Check CBS Registry
            $key = Get-ChildItem "HKLM:Software\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending" -ErrorAction SilentlyContinue
            if ($null -ne $key) 
            {
                $result.CBSRebootPending = $true
            }
    
            #Check Windows Update
            $key = Get-Item 'HKLM:SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired' -ErrorAction SilentlyContinue
            if ($null -ne $key) 
            {
                $result.WindowsUpdateRebootRequired = $true
            }

            #Check PendingFileRenameOperations
            $prop = Get-ItemProperty 'HKLM:SYSTEM\CurrentControlSet\Control\Session Manager' -Name PendingFileRenameOperations -ErrorAction SilentlyContinue
            if ($null -ne $prop) 
            {
                #PendingFileRenameOperations is not *must* to reboot?
                #$result.FileRenamePending = $true
            }
        
            try 
            { 
                $util = [wmiclass]'\\.\root\ccm\clientsdk:CCM_ClientUtilities'
                $status = $util.DetermineIfRebootPending()
                if(($null -ne $status) -and $status.RebootPending){
                    $result.SCCMRebootPending = $true
                }
            }catch{}

            #Return Reboot required
            if ($result.ContainsValue($true)) {
                $text = 'Pending Reboot: Computer is in pending reboot'
                Write-Warning $text
                $log.PendingReboot = 'Pending Reboot'

                if ((Get-XMLConfigPendingRebootApp) -eq $true) {
                    Start-RebootApplication
                    $log.RebootApp = Get-SmallDateTime
                }
            }
            else {
                $text = 'Pending Reboot: OK'
                Write-Output $text
                $log.PendingReboot = 'OK'
            }
            #Out-LogFile -Xml $xml -Text $text
        }
    }

    # Functions to detect and fix errors
    Function Test-ProvisioningMode {
        Param([Parameter(Mandatory=$true)]$Log)
        $registryPath = 'HKLM:\SOFTWARE\Microsoft\CCM\CcmExec'
        $provisioningMode = (Get-ItemProperty -Path $registryPath).ProvisioningMode

        if ($provisioningMode -eq 'true') {
            $text = 'ConfigMgr Client Provisioning Mode: YES. Remediating...'
            Write-Warning $text
            Set-ItemProperty -Path $registryPath -Name ProvisioningMode -Value "false"
            $ArgumentList = @($false)
            Invoke-WmiMethod -Namespace 'root\ccm' -Class 'SMS_Client' -Name 'SetClientProvisioningMode' -ArgumentList $ArgumentList
            $log.ProvisioningMode = 'Repaired'
        }
        else {
            $text = 'ConfigMgr Client Provisioning Mode: OK'
            Write-Output $text
            $log.ProvisioningMode = 'OK'
        }
        #Out-LogFile -Xml $xml -Text $text
    }

    Function Test-UpdateStore {
        Param([Parameter(Mandatory=$true)]$Log)
        Write-Verbose "Check StateMessage.log if State Messages are successfully forwarded to Management Point"
        $StateMessage = Get-Content ('c:\Windows\CCM\Logs\StateMessage.log')
        if ($StateMessage -match 'Successfully forwarded State Messages to the MP') {
            $text = 'StateMessage: OK'
            $log.StateMessages = 'OK'
            Write-Output $text
        }
        else { 
            $text = 'StateMessage: ERROR. Remediating...'
            Write-Warning $text
            $SCCMUpdatesStore = New-Object -ComObject Microsoft.CCM.UpdatesStore
            $SCCMUpdatesStore.RefreshServerComplianceState()
            $log.StateMessages = 'Repaired'
        }
        #Out-LogFile -Xml $xml -Text $text
    } 

    Function Test-RegistryPol {
        Param([Parameter(Mandatory=$true)]$Log)
        $Fixed = $false
        
        # Check 1 - Error in WUAHandler.log
        Write-Verbose 'Check WUAHandler.log if registry.pol need to be deleted'
        $WUAHandler = Get-Content ('c:\Windows\CCM\Logs\WUAHandler.log')
        if ($WUAHandler -match '0x80004005') {
            $text = 'GPO Cache: Error. Deleting registry.pol and run gpupdate...'
            $log.WUAHandler = 'Repaired'
            Write-Warning $text
            try { Remove-Item 'C:\Windows\System32\GroupPolicy\Machine\registry.pol' -Force }
            catch {}
            & gpupdate.exe | Out-Null
            
            Write-Verbose 'Sleeping for 1 minute to allow for group policy to refresh'
            Start-Sleep -Seconds 60

            try {
                Write-Verbose 'Temporarly stopping ccmexec service to allow for deletion of WUAHandler.log'
                Stop-Service -name ccmexec
                Remove-Item 'c:\Windows\CCM\Logs\WUAHandler.log' -Force
                Write-Verbose 'Starting ccmexec service again.'
                Start-Service -Name ccmexec
            }
            catch {}
            
            Write-Verbose 'Refreshing update policy'
            Get-SCCMPolicyScanUpdateSource
            Get-SCCMPolicySourceUpdateMessage
            $Fixed = $true
        }
                
        # Check 2 - Registry.pol is too old. No need to perform this check if check1 performed remediation.
        if ($fixed -eq $false) {
            $file = Get-ChildItem -Path 'C:\Windows\System32\GroupPolicy\Machine\registry.pol' | Select-Object -First 1 -ExpandProperty LastWriteTime
            $regPolDate = Get-Date($file)
            $now = Get-Date
            if (($now - $regPolDate).Days -ge 5) {
                $text = 'GPO Cache: Error. Deleting registry.pol and run gpupdate...'
                Write-Warning $text
                $log.WUAHandler = 'Repaired'
                try { Remove-Item 'C:\Windows\System32\GroupPolicy\Machine\registry.pol' -Force  }
                catch {}
                & gpupdate.exe | Out-Null
                Get-SCCMPolicyScanUpdateSource
                Get-SCCMPolicySourceUpdateMessage
                $Fixed = $true
            }
            
            if ($Fixed -eq $false) {
                $text = 'GPO Cache: OK'
                $log.WUAHandler = 'OK'
                Write-Output $text
            }
        }
    }

    Function Test-ClientLogSize {
        #$Path = 'HKLM:\SOFTWARE\Microsoft\CCM\Logging\@Global'
        try {
            $currentLogSize = Get-ClientMaxLogSize
        } catch {
            $currentLogSize = $false
        }
        try {
            $currentMaxHistory = Get-ClientMaxLogHistory
        } catch {
            $currentMaxHistory = $false
        }
        try {
            $logLevel = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\CCM\Logging\@Global').logLevel
        } catch {
            $logLevel = $false
        }
        #$currentLogSize = Get-ClientMaxLogSize
        #$logLevel = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\CCM\Logging\@Global').logLevel
        $clientLogSize = Get-XMLConfigClientMaxLogSize
        #$currentMaxHistory = Get-ClientMaxLogHistory
        $clientLogMaxHistory = Get-XMLConfigClientMaxLogHistory
        $text = ''

        if ( ($currentLogSize -eq $clientLogSize) -and ($currentMaxHistory -eq $clientLogMaxHistory) ) {
            $text = "ConfigMgr Client Max Log Size: OK"
            Write-Host $text
            #Out-LogFile -Xml $xml -Text $text
            $text = "ConfigMgr Client Max Log History: OK"
            Write-Host $text
            #Out-LogFile -Xml $xml -Text $text
            $obj = $false
        }
        else {
            if ($currentLogSize -ne $clientLogSize) {
                $text = 'ConfigMgr Client Max Log Size: Configuring to '+ $clientLogSize +' KB'
                Write-Warning $text
                #Out-LogFile -Xml $xml -Text $text
            }
            elseif ($currentMaxHistory -ne $clientLogMaxHistory) {
                $text = 'ConfigMgr Client Max Log History: Configuring to ' +$clientLogMaxHistory
                #Out-LogFile -Xml $xml -Text $text
                Write-Warning $text
            }
            $newLogSize = [int]$clientLogSize
            $newLogSize = $newLogSize * 1000

            $smsClient = [wmiclass]"root/ccm:sms_client"
            $smsClient.SetGlobalLoggingConfiguration($logLevel, $newLogSize, $clientLogMaxHistory)
            #Write-Verbose 'Returning true to trigger restart of ccmexec service'
            $obj = $false
        }
        Write-Output $obj
    }

    Function Resolve-Client {
        Param(
            [Parameter(Mandatory=$false)]$Xml,
            [Parameter(Mandatory=$true)]$ClientInstallProperties,
            [Parameter(Mandatory=$false)]$FirstInstall=$false
            )

        $ClientShare = $Xml.Configuration.Client | Where-Object {$_.Name -like 'Share'} | Select-Object -ExpandProperty '#Text'
        if ((Test-Path $ClientShare -ErrorAction SilentlyContinue) -eq $true) {
        if ($FirstInstall -eq $true) {
                $text = 'Installing Configuration Manager Client.'
        } 
        else {
                $text = 'Client tagged for reinstall. Reinstalling client...'
        }
            Write-Output $text
            #Out-LogFile -Xml $xml -Text $text
            Invoke-Expression "$ClientShare\ccmsetup.exe $ClientInstallProperties"
        }
        else {
            $text = 'ERROR: Client tagged for reinstall, but failed to access fileshare: ' +$ClientShare
            Write-Error $text
            #Out-LogFile -Xml $xml -Text $text
            Exit 1
        }
    }

    Function Test-WMI {
        Param([Parameter(Mandatory=$true)]$Log)
        $vote = 0

        $result = winmgmt /verifyrepository
        switch -wildcard ($result) {
            # Always fix if this returns inconsistent
            "*inconsistent*" { $vote = 100}
            "*inkonsekvent*" { $vote = 100}
            # Add more languages as I learn their inconsistent value
        }

        if ($result -match 'inconsistent') {

        }

        Try {
            $WMI = Get-WmiObject Win32_ComputerSystem -ErrorAction Stop
        } Catch {
            Write-Verbose 'Failed to connect to WMI class "Win32_ComputerSystem". Voting for WMI fix...'
            $vote++
        }

        Try {
            $WMI = Get-WmiObject -Namespace root/ccm -Class SMS_Client -ErrorAction Stop
        } Catch {
            Write-Verbose 'Failed to connect to WMI namespace "root/ccm" class "SMS_Client". Tagging client for reinstall instead of WMI fix.'
            $obj = $true
        } Finally {
            if ($vote -eq 0) {
                $text = 'WMI: OK'
                $log.WMI = 'OK'
                Write-Output $text
                $obj = $false
            }
            else {
                $text = 'WMI: ERROR. Attempting to repair WMI and reinstall ConfigMgr client.'
                Write-Warning $text
                Repair-WMI
                Write-Verbose "returning true to tag client for reinstall" 
                $log.WMI = 'Repair'
                $obj = $true
            }
            #Out-LogFile -Xml $xml -Text $text
            Write-Output $obj
        }
    }

    Function Repair-WMI {
        $text ='Repairing WMI'
        Write-Output $text
        #Out-LogFile -Xml $xml -Text $text
        
        # Check PATH
        if((! (@(($ENV:PATH).Split(";")) -contains "c:\WINDOWS\System32\Wbem")) -and (! (@(($ENV:PATH).Split(";")) -contains "%systemroot%\System32\Wbem"))){
            $text = "WMI Folder not in search path!."
            #Out-LogFile -Xml $xml -Text $text
            Write-Warning $text
        }
        # Stop WMI
        Stop-Service -Force ccmexec -ErrorAction SilentlyContinue 
        Stop-Service -Force winmgmt

        # WMI Binaries
        [String[]]$aWMIBinaries=@("unsecapp.exe","wmiadap.exe","wmiapsrv.exe","wmiprvse.exe","scrcons.exe")
        foreach ($sWMIPath in @(($ENV:SystemRoot+"\System32\wbem"),($ENV:SystemRoot+"\SysWOW64\wbem"))) {
            if(Test-Path -Path $sWMIPath){
                push-Location $sWMIPath
                foreach($sBin in $aWMIBinaries){
                    if(Test-Path -Path $sBin){
                        $oCurrentBin=Get-Item -Path  $sBin
                        #Write-Verbose "Register $sBin"
                        & $oCurrentBin.FullName /RegServer
                    }
                    else{
                        # Warning only for System32
                        if($sWMIPath -eq $ENV:SystemRoot+"\System32\wbem"){
                            Write-Warning "File $sBin not found!"
                        }
                    }
                }
                Pop-Location
            }
        }

        # Reregister Managed Objects
        Write-Verbose "Reseting Repository..."
        & ($ENV:SystemRoot+"\system32\wbem\winmgmt.exe") /resetrepository
        & ($ENV:SystemRoot+"\system32\wbem\winmgmt.exe") /salvagerepository
        Start-Service winmgmt
        $text = 'Tagging ConfigMgr client for reinstall'
        #Out-LogFile -Xml $xml -Text $text
        Write-Warning $text
    }

    # Start ConfigMgr Agent if not already running
    Function Test-SCCMService {
        if ($service.Status -ne 'Running') {
            try {Start-Service -Name CcmExec | Out-Null}
            catch {}
        }
    }

    # Windows Service Functions
    Function Test-Services {
        Param([Parameter(Mandatory=$true)]$Xml, $log)

        $log.Services = 'OK'
        Write-Verbose 'Test services from XML configuration file'
        foreach ($service in $Xml.Configuration.Service) {
            Test-Service -Name $service.Name -StartupType $service.StartupType -State $service.State -Log $log
        }
    }

    Function Test-Service {
        param(
        [Parameter(Mandatory=$True,
                    HelpMessage='Name')]
                    [string]$Name,
        [Parameter(Mandatory=$True,
                    HelpMessage='StartupType: Automatic, Manual, Disabled')]
                    [string]$StartupType,
        [Parameter(Mandatory=$True,
                    HelpMessage='State: Running, Stopped')]
                    [string]$State,
        [Parameter(Mandatory=$True)]$log
        )

        $service = Get-Service -Name $Name
        $WMIService = Get-WmiObject -Class Win32_Service -Property StartMode -Filter "Name='$Name'"
        
        switch ($WMIService.StartMode) {
            Auto {$serviceStartType = "Automatic"}
            Manual {$serviceStartType = "Manual"}
            Disabled {$serviceStartType = "Disabled"}
        }

        Write-Verbose "Verify startup type"
        if ($serviceStartType -eq $StartupType)
        {
            $text = "Service $Name startup: OK"
            #Out-LogFile -Xml $xml -Text $text
            Write-Output $text
        }
        else {
            try {
                $text = "Configuring service $Name StartupType to: $StartupType..."
                Write-Output $text
                Set-Service -Name $service.Name -StartupType $StartupType
                $log.Services = 'Started'
            } catch {
                $text = "Failed to set $StartupType StartupType on service $Name"
                Write-Error $text
            } finally {
                #Out-LogFile -Xml $xml -Text $text
            }
        }
        
        Write-Verbose 'Verify service is running'
        if ($service.Status -eq "Running") {
            $text = 'Service ' +$Name+' running: OK'
            Write-Output $text
        }
        else {
            try {
                $text = 'Starting service: ' + $Name + '...'
                Write-Output $text
                Start-Service -Name $service.Name
                $log.Services = 'Started'
            } catch {
                $text = 'Failed to start service ' +$Name
                Write-Error $text
            }
        }
        #Out-LogFile -Xml $xml -Text $text
    }

    function Test-AdminShare {
        Param([Parameter(Mandatory=$true)]$Log)
        Write-Verbose "Test the ADMIN$ and C$"

        $share = Get-WmiObject Win32_Share | Where-Object {$_.Name -like 'ADMIN$'}
        $shareClass = [WMICLASS]”WIN32_Share”

        if ($share.Name -contains 'ADMIN$') {
            $text = 'Adminshare Admin$: OK'
            #Out-LogFile -Xml $xml -Text $text
            Write-Output $text
        }
        else {
            $fix = $true
        }
        
        $share = Get-WmiObject Win32_Share | Where-Object {$_.Name -like 'C$'}
        $shareClass = [WMICLASS]'WIN32_Share'

        if ($share.Name -contains "C$") {
            $text = 'Adminshare C$: OK'
            #Out-LogFile -Xml $xml -Text $text
            Write-Output $text
        }
        else {
            $fix = $true
        }

        if ($fix -eq $true) {
            $text = 'Error with Adminshares. Remediating...'
            $log.AdminShare = 'Repaired'
            #Out-LogFile -Xml $xml -Text $text
            Write-Warning $text
            Stop-Service server -Force
            Start-Service server
        }
        else {
            $log.AdminShare = 'OK'
        }
    }

    Function Test-DiskSpace {
        $XMLDiskSpace = Get-XMLConfigOSDiskFreeSpace
        $driveC = Get-WmiObject -Class Win32_LogicalDisk | Where-Object {$_.DeviceID -eq 'C:'} | Select-Object FreeSpace, Size
        $freeSpace = (($driveC.FreeSpace / $driveC.Size) * 100)

        if ($freeSpace -le $XMLDiskSpace) {
            $text = 'Local disk C: Less than '+$XMLDiskSpace +'% free space'
            Write-Error $text
        }
        else {
            $text = 'Free space C: OK'
            Write-Output $text
        }
        #Out-LogFile -Xml $xml -Text $text
    }

    Function Test-CCMSoftwareDistribution {
        Get-WmiObject -Class CCM_SoftwareDistributionClientConfig
    }

    Function Get-LastReboot {
        Param([Parameter(Mandatory=$true)][xml]$Xml)

        # Only run if option in config is enabled
        if (($Xml.Configuration.Option | Where-Object {$_.Name -like 'RebootApplication'} | Select-Object -ExpandProperty 'Enable') -like 'True') {

            [float]$maxRebootDays = Get-XMLConfigMaxRebootDays
            $wmi = Get-WmiObject Win32_OperatingSystem
            $lastBootTime = $wmi.ConvertToDateTime($wmi.LastBootUpTime)

            $uptime = (Get-Date) - ($wmi.ConvertToDateTime($wmi.lastbootuptime))
            if ($uptime.TotalDays -lt $maxRebootDays) {
                $text = 'Last boot time: ' +$lastBootTime + ': OK'
                Write-Output $text
            }
            elseif (($uptime.TotalDays -ge $maxRebootDays) -and (Get-XMLConfigRebootApplicationEnable -eq $true)) {
                $text = 'Last boot time: ' +$lastBootTime + ': More than '+$maxRebootDays +' days since last reboot. Starting reboot application.'
                Write-Warning $text
                Start-RebootApplication
            }
            else {
                $text = 'Last boot time: ' +$lastBootTime + ': More than '+$maxRebootDays +' days since last reboot. Reboot application disabled.'
                Write-Warning $text
            }
        }
    }

    Function Start-RebootApplication {
        $taskName = 'ConfigMgr Client Health - Reboot on demand'
        $task = Get-ScheduledTask -TaskName $taskName
        if ($task -eq $null) {
            New-RebootTask -taskName $taskName
        }
        
        Start-ScheduledTask -TaskName $taskName
    }

    Function New-RebootTask {
        Param([Parameter(Mandatory=$true)]$taskName)

        $rebootApp = Get-XMLConfigRebootApplication
        $execute,$arguments = $rebootApp.Split(' ')
        $argument = $null

        foreach ($i in $arguments) {
            $argument += $i + " "
        }

        # Trim the " " from argument if present
        $i = $argument.Length -1
        if ($argument.Substring($i) -eq ' ') {
            $argument = $argument.Substring(0, $argument.Length -1)
        }

        $action = New-ScheduledTaskAction -Execute $execute -Argument $argument
        $userPrincipal = New-ScheduledTaskPrincipal -GroupId "S-1-5-32-545"

        Register-ScheduledTask -Action $action -TaskName $taskName -Principal $userPrincipal | Out-Null
    }

    Function Test-MissingDrivers {
        Param([Parameter(Mandatory=$true)]$Log)
        $i = 0
        $devices = Get-WmiObject Win32_PNPEntity | Where-Object{ ($_.ConfigManagerErrorCode -ne 0) -and ($_.ConfigManagerErrorCode -ne 22) -and ($_.Name -notlike "*PS/2*") } | Select-Object Name, DeviceID
        $devices | ForEach-Object {$i++} 

        if ($devices -ne $null) {
            $text = "Drivers: $i unknown or faulty device(s)" 
            Write-Warning $text
            #Out-LogFile -Xml $xml -Text $text
            $log.Drivers = "$i unknown or faulty driver(s)" 
            
            foreach ($device in $devices) {
                $text = 'Missing or faulty driver: ' +$device.Name + '. Device ID: ' + $device.DeviceID
                Write-Warning $text
                Out-LogFile -Xml $xml -Text $text
            }
        }
        else {
            $text = "Drivers: OK"
            Write-Output $text
            #Out-LogFile -Xml $xml -Text $text
            $log.Drivers = 'OK' 
        }
    }

    Function Test-SCCMHardwareInventoryScan {
        Param([Parameter(Mandatory=$true)]$Log)
        $days = Get-XMLConfigHardwareInventoryDays

        $wmi = Get-WmiObject -Namespace root\ccm\invagt -Class InventoryActionStatus | Where-Object {$_.InventoryActionID -eq '{00000000-0000-0000-0000-000000000001}'} | Select-Object @{label='HWSCAN';expression={$_.ConvertToDateTime($_.LastCycleStartedDate)}}
        $HWScanDate = $wmi | Select-Object -ExpandProperty HWSCAN
        $HWScanDate = Get-SmallDateTime $HWScanDate
        $minDate = Get-SmallDateTime((Get-Date).AddDays(-$days))
        if ($HWScanDate -le $minDate) {
            $text = "ConfigMgr Hardware Inventory scan: $HWScanDate. Starting hardware inventory scan of the client."
            Write-Warning $Text
            Get-SCCMPolicyHardwareInventory
            
            # Get the new date after policy trigger
            $wmi = Get-WmiObject -Namespace root\ccm\invagt -Class InventoryActionStatus | Where-Object {$_.InventoryActionID -eq '{00000000-0000-0000-0000-000000000001}'} | Select-Object @{label='HWSCAN';expression={$_.ConvertToDateTime($_.LastCycleStartedDate)}}
            $HWScanDate = $wmi | Select-Object -ExpandProperty HWSCAN
            $HWScanDate = Get-SmallDateTime $HWScanDate            
        }
        else {
            $text = "ConfigMgr Hardware Inventory scan: OK"
            Write-Output $text
        }
        $log.HWInventory = $HWScanDate
    }

    Function Test-SCCMHWScanErrors {
        # Function to test and fix errors that prevent a computer to perform a HW scan. Not sure if this is really needed or not.
    }

    # SCCM Client evaluation policies
    Function Get-SCCMPolicySourceUpdateMessage {
        $trigger = "{00000000-0000-0000-0000-000000000032}"
        Invoke-WmiMethod -Namespace root\ccm -Class sms_client -Name TriggerSchedule $trigger -ErrorAction SilentlyContinue | Out-Null
    }

    Function Get-SCCMPolicySendUnsentStateMessages {
        $trigger = "{00000000-0000-0000-0000-000000000111}"
        Invoke-WmiMethod -Namespace root\ccm -Class sms_client -Name TriggerSchedule $trigger -ErrorAction SilentlyContinue | Out-Null
    }

    Function Get-SCCMPolicyScanUpdateSource {
        $trigger = "{00000000-0000-0000-0000-000000000113}"
        Invoke-WmiMethod -Namespace root\ccm -Class sms_client -Name TriggerSchedule $trigger -ErrorAction SilentlyContinue | Out-Null
    }

    Function Get-SCCMPolicyHardwareInventory {
        $trigger = "{00000000-0000-0000-0000-000000000001}"
        Invoke-WmiMethod -Namespace root\ccm -Class sms_client -Name TriggerSchedule $trigger -ErrorAction SilentlyContinue | Out-Null
    }

    Function Get-SCCMPolicyMachineEvaluation {
        $trigger = "{00000000-0000-0000-0000-000000000022}"
        Invoke-WmiMethod -Namespace root\ccm -Class sms_client -Name TriggerSchedule $trigger -ErrorAction SilentlyContinue | Out-Null
    }

    Function Get-Version {
        $text = 'ConfigMgr Client Health Version ' +$Version
        Write-Output $text
        Out-LogFile -Xml $xml -Text $text
    }

    <# Trigger codes
    {00000000-0000-0000-0000-000000000001} Hardware Inventory
    {00000000-0000-0000-0000-000000000002} Software Inventory 
    {00000000-0000-0000-0000-000000000003} Discovery Inventory 
    {00000000-0000-0000-0000-000000000010} File Collection 
    {00000000-0000-0000-0000-000000000011} IDMIF Collection 
    {00000000-0000-0000-0000-000000000012} Client Machine Authentication 
    {00000000-0000-0000-0000-000000000021} Request Machine Assignments 
    {00000000-0000-0000-0000-000000000022} Evaluate Machine Policies 
    {00000000-0000-0000-0000-000000000023} Refresh Default MP Task 
    {00000000-0000-0000-0000-000000000024} LS (Location Service) Refresh Locations Task 
    {00000000-0000-0000-0000-000000000025} LS (Location Service) Timeout Refresh Task 
    {00000000-0000-0000-0000-000000000026} Policy Agent Request Assignment (User) 
    {00000000-0000-0000-0000-000000000027} Policy Agent Evaluate Assignment (User) 
    {00000000-0000-0000-0000-000000000031} Software Metering Generating Usage Report 
    {00000000-0000-0000-0000-000000000032} Source Update Message
    {00000000-0000-0000-0000-000000000037} Clearing proxy settings cache 
    {00000000-0000-0000-0000-000000000040} Machine Policy Agent Cleanup 
    {00000000-0000-0000-0000-000000000041} User Policy Agent Cleanup
    {00000000-0000-0000-0000-000000000042} Policy Agent Validate Machine Policy / Assignment 
    {00000000-0000-0000-0000-000000000043} Policy Agent Validate User Policy / Assignment 
    {00000000-0000-0000-0000-000000000051} Retrying/Refreshing certificates in AD on MP 
    {00000000-0000-0000-0000-000000000061} Peer DP Status reporting 
    {00000000-0000-0000-0000-000000000062} Peer DP Pending package check schedule 
    {00000000-0000-0000-0000-000000000063} SUM Updates install schedule 
    {00000000-0000-0000-0000-000000000071} NAP action 
    {00000000-0000-0000-0000-000000000101} Hardware Inventory Collection Cycle 
    {00000000-0000-0000-0000-000000000102} Software Inventory Collection Cycle 
    {00000000-0000-0000-0000-000000000103} Discovery Data Collection Cycle 
    {00000000-0000-0000-0000-000000000104} File Collection Cycle 
    {00000000-0000-0000-0000-000000000105} IDMIF Collection Cycle 
    {00000000-0000-0000-0000-000000000106} Software Metering Usage Report Cycle 
    {00000000-0000-0000-0000-000000000107} Windows Installer Source List Update Cycle 
    {00000000-0000-0000-0000-000000000108} Software Updates Assignments Evaluation Cycle 
    {00000000-0000-0000-0000-000000000109} Branch Distribution Point Maintenance Task 
    {00000000-0000-0000-0000-000000000110} DCM policy 
    {00000000-0000-0000-0000-000000000111} Send Unsent State Message 
    {00000000-0000-0000-0000-000000000112} State System policy cache cleanout 
    {00000000-0000-0000-0000-000000000113} Scan by Update Source 
    {00000000-0000-0000-0000-000000000114} Update Store Policy 
    {00000000-0000-0000-0000-000000000115} State system policy bulk send high
    {00000000-0000-0000-0000-000000000116} State system policy bulk send low 
    {00000000-0000-0000-0000-000000000120} AMT Status Check Policy 
    {00000000-0000-0000-0000-000000000121} Application manager policy action 
    {00000000-0000-0000-0000-000000000122} Application manager user policy action
    {00000000-0000-0000-0000-000000000123} Application manager global evaluation action 
    {00000000-0000-0000-0000-000000000131} Power management start summarizer
    {00000000-0000-0000-0000-000000000221} Endpoint deployment reevaluate 
    {00000000-0000-0000-0000-000000000222} Endpoint AM policy reevaluate 
    {00000000-0000-0000-0000-000000000223} External event detection
    #>

    function Test-SQLConnection {    
        $SQLServer = Get-XMLConfigSQLServer
        $Database = 'ClientHealth'

        $ConnectionString = "Server={0};Database={1};Integrated Security=True;" -f $SQLServer,$Database

        try
        {
            $sqlConnection = New-Object System.Data.SqlClient.SqlConnection $ConnectionString;
            $sqlConnection.Open();
            $sqlConnection.Close();

            $obj = $true;
        } catch {
            $text = "Error connecting to SQLDatabase $Database on SQL Server $SQLServer"
            Write-Error -Message $text
            Out-LogFile -Xml $xml -Text $text
            $obj = $false;
        } finally {
            Write-Output $obj
        }
    }

    # Invoke-SqlCmd2 - Created by Chad Miller
    function Invoke-Sqlcmd2 
    { 
        [CmdletBinding()] 
        param( 
        [Parameter(Position=0, Mandatory=$true)] [string]$ServerInstance, 
        [Parameter(Position=1, Mandatory=$false)] [string]$Database, 
        [Parameter(Position=2, Mandatory=$false)] [string]$Query, 
        [Parameter(Position=3, Mandatory=$false)] [string]$Username, 
        [Parameter(Position=4, Mandatory=$false)] [string]$Password, 
        [Parameter(Position=5, Mandatory=$false)] [Int32]$QueryTimeout=600, 
        [Parameter(Position=6, Mandatory=$false)] [Int32]$ConnectionTimeout=15, 
        [Parameter(Position=7, Mandatory=$false)] [ValidateScript({test-path $_})] [string]$InputFile, 
        [Parameter(Position=8, Mandatory=$false)] [ValidateSet("DataSet", "DataTable", "DataRow")] [string]$As="DataRow" 
        ) 
    
        if ($InputFile) 
        { 
            $filePath = $(resolve-path $InputFile).path 
            $Query =  [System.IO.File]::ReadAllText("$filePath") 
        } 
    
        $conn=new-object System.Data.SqlClient.SQLConnection 
        
        if ($Username) 
        { $ConnectionString = "Server={0};Database={1};User ID={2};Password={3};Trusted_Connection=False;Connect Timeout={4}" -f $ServerInstance,$Database,$Username,$Password,$ConnectionTimeout } 
        else 
        { $ConnectionString = "Server={0};Database={1};Integrated Security=True;Connect Timeout={2}" -f $ServerInstance,$Database,$ConnectionTimeout } 
    
        $conn.ConnectionString=$ConnectionString 
        
        #Following EventHandler is used for PRINT and RAISERROR T-SQL statements. Executed when -Verbose parameter specified by caller 
        if ($PSBoundParameters.Verbose) 
        { 
            $conn.FireInfoMessageEventOnUserErrors=$true 
            $handler = [System.Data.SqlClient.SqlInfoMessageEventHandler] {Write-Verbose "$($_)"} 
            $conn.add_InfoMessage($handler) 
        } 
        
        $conn.Open() 
        $cmd=new-object system.Data.SqlClient.SqlCommand($Query,$conn) 
        $cmd.CommandTimeout=$QueryTimeout 
        $ds=New-Object system.Data.DataSet 
        $da=New-Object system.Data.SqlClient.SqlDataAdapter($cmd) 
        [void]$da.fill($ds) 
        $conn.Close() 
        switch ($As) 
        { 
            'DataSet'   { Write-Output ($ds) } 
            'DataTable' { Write-Output ($ds.Tables) } 
            'DataRow'   { Write-Output ($ds.Tables[0]) } 
        } 
    }


    # Gather info about the computer
    Function Get-Info {
        $OS = Get-WmiObject Win32_OperatingSystem
        $ComputerSystem = Get-WmiObject Win32_ComputerSystem

        if ($ComputerSystem.Manufacturer -like 'Lenovo') {
            $Model = (Get-WmiObject Win32_ComputerSystemProduct).Version
        }
        else {
            $Model = $ComputerSystem.Model
        }

        $obj = New-Object PSObject -Property @{
            Hostname = $ComputerSystem.Name;
            Manufacturer = $ComputerSystem.Manufacturer
            Model = $Model
            Operatingsystem = $OS.Caption;
            Architecture = $OS.OSArchitecture;
            Build = $OS.BuildNumber;
            InstallDate = $OS.ConvertToDateTime($OS.InstallDate);
            LastLoggedOnUser = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\LogonUI\').LastLoggedOnUser;
        }

        $obj = $obj
        Write-Output $obj
    }

    # Start Getters - XML config file
    Function Get-XMLConfigClientVersion {
        $obj = $Xml.Configuration.Client | Where-Object {$_.Name -like 'Version'} | Select-Object -ExpandProperty '#text'
        Write-Output $obj
    }

    Function Get-XMLConfigClientSitecode {
        $obj = $Xml.Configuration.Client | Where-Object {$_.Name -like 'SiteCode'} | Select-Object -ExpandProperty '#text'
        Write-Output $obj
    }

    Function Get-XMLConfigClientDomain {
        $obj = $Xml.Configuration.Client | Where-Object {$_.Name -like 'Domain'} | Select-Object -ExpandProperty '#text'
        Write-Output $obj
    }

    Function Get-XMLConfigClientAutoUpgrade {
        $obj = $Xml.Configuration.Client | Where-Object {$_.Name -like 'AutoUpgrade'} | Select-Object -ExpandProperty '#text'
        Write-Output $obj
    }

    Function Get-XMLConfigClientMaxLogSize {
        $obj = $Xml.Configuration.Client | Where-Object {$_.Name -like 'Log'} | Select-Object -ExpandProperty 'MaxLogSize'
        Write-Output $obj
    }

    Function Get-XMLConfigClientMaxLogHistory {
        $obj = $Xml.Configuration.Client | Where-Object {$_.Name -like 'Log'} | Select-Object -ExpandProperty 'MaxLogHistory'
        Write-Output $obj
    }

    Function Get-XMLConfigClientMaxLogSizeEnabled {
        $obj = $Xml.Configuration.Client | Where-Object {$_.Name -like 'Log'} | Select-Object -ExpandProperty 'Enable'
        Write-Output $obj
    }

    Function Get-XMLConfigClientCache {
        $obj = $Xml.Configuration.Client | Where-Object {$_.Name -like 'CacheSize'} | Select-Object -ExpandProperty '#text'
        Write-Output $obj
    }

    Function Get-XMLConfigClientShare {
        $obj = $Xml.Configuration.Client | Where-Object {$_.Name -like 'Share'} | Select-Object -ExpandProperty '#text'
        Write-Output $obj
    }

    Function Get-XMLConfigUpdatesShare {
        $obj = $Xml.Configuration.Option | Where-Object {$_.Name -like 'Updates'} | Select-Object -ExpandProperty 'Share'
        Write-Output $obj
    }

    Function Get-XMLConfigUpdatesEnable {
        $obj = $Xml.Configuration.Option | Where-Object {$_.Name -like 'Updates'} | Select-Object -ExpandProperty 'Enable'
        Write-Output $obj
    }

    Function Get-XMLConfigLoggingShare {
        $obj = $Xml.Configuration.Log | Where-Object {$_.Name -like 'File'} | Select-Object -ExpandProperty 'Share'
        Write-Output $obj
    }

    Function Get-XMLConfigLoggingEnable {
        $obj = $Xml.Configuration.Log | Where-Object {$_.Name -like 'File'} | Select-Object -ExpandProperty 'Enable'
        Write-Output $obj
    }

    Function Get-XMLConfigLoggingMaxHistory {
        $obj = $Xml.Configuration.Log | Where-Object {$_.Name -like 'File'} | Select-Object -ExpandProperty 'MaxLogHistory'
        Write-Output $obj
    }

    Function Get-XMLConfigLogginLevel {
        $obj = $Xml.Configuration.Log | Where-Object {$_.Name -like 'File'} | Select-Object -ExpandProperty 'Level'
        Write-Output $obj
    }

    Function Get-XMLConfigPendingRebootApp {
        $obj = $Xml.Configuration.Option | Where-Object {$_.Name -like 'PendingReboot'} | Select-Object -ExpandProperty 'StartRebootApplication'
        Write-Output $obj
    }

    Function Get-XMLConfigMaxRebootDays {
        $obj = $Xml.Configuration.Option | Where-Object {$_.Name -like 'MaxRebootDays'} | Select-Object -ExpandProperty 'Days'
        Write-Output $obj
    }

    Function Get-XMLConfigRebootApplication {
        $obj = $Xml.Configuration.Option | Where-Object {$_.Name -like 'RebootApplication'} | Select-Object -ExpandProperty 'Application'
        Write-Output $obj
    }

    Function Get-XMLConfigRebootApplicationEnable {
        $obj = $Xml.Configuration.Option | Where-Object {$_.Name -like 'RebootApplication'} | Select-Object -ExpandProperty 'Enable'
        Write-Output $obj
    }

    Function Get-XMLConfigDNSCheck {
        $obj = $Xml.Configuration.Option | Where-Object {$_.Name -like 'DNSCheck'} | Select-Object -ExpandProperty 'Enable'
        Write-Output $obj
    }

    Function Get-XMLConfigDrivers {
        $obj = $Xml.Configuration.Option | Where-Object {$_.Name -like 'Drivers'} | Select-Object -ExpandProperty 'Enable'
        Write-Output $obj
    }

    Function Get-XMLConfigOSDiskFreeSpace {
        $obj = $Xml.Configuration.Option | Where-Object {$_.Name -like 'OSDiskFreeSpace'} | Select-Object -ExpandProperty '#text'
        Write-Output $obj
    }

    Function Get-XMLConfigHardwareInventoryEnable {
        $obj = $Xml.Configuration.Option | Where-Object {$_.Name -like 'HardwareInventory'} | Select-Object -ExpandProperty 'Enable'
        Write-Output $obj
    }

    Function Get-XMLConfigHardwareInventoryDays {
        $obj = $Xml.Configuration.Option | Where-Object {$_.Name -like 'HardwareInventory'} | Select-Object -ExpandProperty 'Days'
        Write-Output $obj
    }

    Function Get-XMLConfigRemediationAdminShare {
        $obj = $Xml.Configuration.Remediation | Where-Object {$_.Name -like 'AdminShare'} | Select-Object -ExpandProperty 'Fix'
        Write-Output $obj
    }

    Function Get-XMLConfigRemediationClientProvisioningMode {
        $obj = $Xml.Configuration.Remediation | Where-Object {$_.Name -like 'ClientProvisioningMode'} | Select-Object -ExpandProperty 'Fix'
        Write-Output $obj
    }

    Function Get-XMLConfigRemediationClientStateMessages {
        $obj = $Xml.Configuration.Remediation | Where-Object {$_.Name -like 'ClientStateMessages'} | Select-Object -ExpandProperty 'Fix'
        Write-Output $obj
    }

    Function Get-XMLConfigRemediationClientWUAHandler {
        $obj = $Xml.Configuration.Remediation | Where-Object {$_.Name -like 'ClientWUAHandler'} | Select-Object -ExpandProperty 'Fix'
        Write-Output $obj
    }

    Function Get-XMLConfigRemediationWMI {
        $obj = $Xml.Configuration.Remediation | Where-Object {$_.Name -like 'WMI'} | Select-Object -ExpandProperty 'Fix'
        Write-Output $obj
    }

    Function Get-XMLConfigRemediationClientCertificate {
        $obj = $Xml.Configuration.Remediation | Where-Object {$_.Name -like 'ClientCertificate'} | Select-Object -ExpandProperty 'Fix'
        Write-Output $obj
    }

    Function Get-XMLConfigSQLServer {
        $obj = $Xml.Configuration.Log | Where-Object {$_.Name -like 'SQL'} | Select-Object -ExpandProperty 'Server'
        Write-Output $obj
    }

    Function Get-XMLConfigSQLLoggingEnable {
        $obj = $Xml.Configuration.Log | Where-Object {$_.Name -like 'SQL'} | Select-Object -ExpandProperty 'Enable'
        Write-Output $obj
    }



    # End Getters - XML config file

    Function GetComputerInfo {
        $info = Get-Info | Select-Object HostName, OperatingSystem, Architecture, Build, InstallDate, Manufacturer, Model, LastLoggedOnUser
        #$text = 'Computer info'+ "`n"
        $text = 'Hostname: ' +$info.HostName
        Write-Output $text
        #Out-LogFile -Xml $xml $text
        $text = 'Operatingsystem: ' +$info.OperatingSystem
        Write-Output $text
        #Out-LogFile -Xml $xml $text
        $text = 'Architecture: ' + $info.Architecture
        Write-Output $text
        #Out-LogFile -Xml $xml $text
        $text = 'Build: ' + $info.Build
        Write-Output $text
        #Out-LogFile -Xml $xml $text
        $text = 'Manufacturer: ' + $info.Manufacturer
        Write-Output $text
        #Out-LogFile -Xml $xml $text
        $text = 'Model: ' + $info.Model
        Write-Output $text
        #Out-LogFile -Xml $xml $text
        $text = 'InstallDate: ' + $info.InstallDate
        Write-Output $text
        #Out-LogFile -Xml $xml $text
        $text = 'LastLoggedOnUser: ' + $info.LastLoggedOnUser
        Write-Output $text
        #Out-LogFile -Xml $xml $text
    }

    Function Start-ConfigMgrHealth {
        Test-LogFileHistory
        Out-LogFile -Xml  $xml -Text "<--- ConfigMgr Client Health Check starting --->"
    }
   
    Function Stop-ConfigMgrHealth {
        $text = '<--- ConfigMgr Client Health Check finished --->'
    }

    Function CleanUp {
        if ((Test-Path 'C:\Temp\ClientHealth' -ErrorAction SilentlyContinue) -eq $True) {
            Remove-Item 'C:\Temp\ClientHealth' -Force | Out-Null
        }
    }

    Function New-LogObject {

        $OS = Get-WmiObject -class Win32_OperatingSystem
        $CS = Get-WmiObject -class Win32_ComputerSystem
        
        # Handles different OS languages
        $Hostname = Get-Computername
        $OperatingSystem = $OS.Caption
        $Architecture = ($OS.OSArchitecture -replace ('([^0-9])(\.*)', '')) + '-Bit'
        $Build = $OS.BuildNumber
        $Manufacturer = $CS.Manufacturer
        $Model = $CS.Model
        $ClientVersion = 'Unknown'
        $Sitecode = Get-Sitecode
        $Domain = Get-Domain
        $MaxLogSize = Get-ClientMaxLogSize
        $MaxLogHistory = Get-ClientMaxLogHistory
        $InstallDate = $OS.ConvertToDateTime($OS.InstallDate).ToString("yyyy-MM-dd HH:mm:ss")
        $InstallDate = $InstallDate -replace '\.', ':'
        $LastLoggedOnUser = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\LogonUI\').LastLoggedOnUser
        $CacheSize = Get-ClientCache
        $Services = 'Unknown'
        $Updates = 'Unknown'
        $DNS = 'Unknown'
        $Drivers = 'Unknown'
        $Certificate = 'Unknown'
        $PendingReboot = 'Unknown'
        $RebootApp = 'Unknown'
        $LastBootTime = $OS.ConvertToDateTime($OS.LastBootUpTime).ToString("yyyy-MM-dd HH:mm:ss")
        $LastBootTime = $LastBootTime -replace '\.', ':'
        $OSDiskFreeSpace = Get-OSDiskFreeSpace
        $AdminShare = 'Unknown'
        $ProvisioningMode = 'Unknown'
        $StateMessages = 'Unknown'
        $WUAHandler = 'Unknown'
        $WMI = 'Unknown'
        $Updates = 'Unknown'
        $Services = 'Unknown'
        $smallDateTime = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        $smallDateTime = $smallDateTime -replace '\.', ':'
        [float]$PSVersion = [float]$psVersion = [float]$PSVersionTable.PSVersion.Major + ([float]$PSVersionTable.PSVersion.Minor / 10)
        [int]$PSBuild = [int]$PSVersionTable.PSVersion.Build
        if ($PSBuild -le 0) {
            $PSBuild = $null
        }

        $obj = New-Object PSObject -Property @{
            Hostname = $Hostname
            Operatingsystem = $OperatingSystem
            Architecture = $Architecture
            Build = $Build
            Manufacturer = $Manufacturer
            Model = $Model
            InstallDate = $InstallDate 
            LastLoggedOnUser = $LastLoggedOnUser
            ClientVersion = $ClientVersion
            Sitecode = $Sitecode
            Domain = $Domain
            MaxLogSize = $MaxLogSize
            MaxLogHistory = $MaxLogHistory
            CacheSize = $CacheSize
            Certificate = $Certificate
            ProvisioningMode = $ProvisioningMode
            DNS = $DNS
            Drivers = $Drivers
            Updates = $Updates
            PendingReboot = $PendingReboot
            RebootApp = $RebootApp
            LastBootTime = $LastBootTime
            OSDiskFreeSpace = $OSDiskFreeSpace
            AdminShare = $AdminShare
            StateMessages = $StateMessages
            WUAHandler = $WUAHandler
            WMI = $WMI
            Timestamp = $smallDateTime
            Version = 'Unknown'
            Services = $Services
            PSVersion = $PSVersion
            PSBuild = $PSBuild
            OSUpdates = $null
            HWInventory = $null
            ClientInstalled = $null
        }
        Write-Output $obj
    }

    Function Get-SmallDateTime {
        Param([Parameter(Mandatory=$false)]$Date)
        if ($null -ne $Date) {
            $obj = ($Date).ToString("yyyy-MM-dd HH:mm:ss")
        }
        else {
            $obj = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        }
        $obj = $obj -replace '\.', ':'
        Write-Output $obj
    }

    Function Update-SQL {
        Param(
            [Parameter(Mandatory=$true)]$Log,
            [Parameter(Mandatory=$false)]$Table
            )
        $SQLServer = Get-XMLConfigSQLServer
        $Database = 'ClientHealth'
        $table = 'dbo.Clients'
        $smallDateTime = Get-SmallDateTime
        
        if ($null -ne $log.OSUpdates) {
            # UPDATE
            $q1 = "OSUpdates='"+$log.OSUpdates+"', "
            # INSERT INTO
            $q2 = "OSUpdates, "
            # VALUES
            $q3 = "'"+$log.OSUpdates+"', "
        }
        else {
            $q1 = $null
            $q2 = $null
            $q3 = $null
        }

        if ($null -ne $log.ClientInstalled) {
            # UPDATE
            $q10 = "ClientInstalled='"+$log.ClientInstalled+"', "
            # INSERT INTO
            $q20 = "ClientInstalled, "
            # VALUES
            $q30 = "'"+$log.ClientInstalled+"', "
        }
        else {
            $q10 = $null
            $q20 = $null
            $q30 = $null
        }
        
        $query= "begin tran
        if exists (SELECT * FROM $table WITH (updlock,serializable) WHERE Hostname='"+$log.Hostname+"')
        begin
            UPDATE $table SET Operatingsystem='"+$log.Operatingsystem+"', Architecture='"+$log.Architecture+"', Build='"+$log.Build+"',Manufacturer='"+$log.Manufacturer+"', Model='"+$log.Model+"', InstallDate='"+$log.InstallDate+"', $q1 LastLoggedOnUser='"+$log.LastLoggedOnUser+"', ClientVersion='"+$log.ClientVersion+"', PSVersion='"+$log.PSVersion+"', PSBuild='"+$log.PSBuild+"', Sitecode='"+$log.Sitecode+"', Domain='"+$log.Domain+"', MaxLogSize='"+$log.MaxLogSize+"', MaxLogHistory='"+$log.MaxLogHistory+"', CacheSize='"+$log.CacheSize+"', ClientCertificate='"+$log.Certificate+"', ProvisioningMode='"+$log.ProvisioningMode+"', DNS='"+$log.DNS+"', Drivers='"+$log.Drivers+"', Updates='"+$log.Updates+"', PendingReboot='"+$log.PendingReboot+"', LastBootTime='"+$log.LastBootTime+"', OSDiskFreeSpace='"+$log.OSDiskFreeSpace+"', Services='"+$log.Services+"', AdminShare='"+$log.AdminShare+"', StateMessages='"+$log.StateMessages+"', WUAHandler='"+$log.WUAHandler+"', WMI='"+$log.WMI+"',HWInventory='"+$log.HWInventory+"',  Version='"+$Version+"', $q10 Timestamp='"+$smallDateTime+"'
            WHERE Hostname = '"+$log.Hostname+"'
        end
        else
        begin
            INSERT INTO $table (Hostname, Operatingsystem, Architecture, Build, Manufacturer, Model, InstallDate, $q2 LastLoggedOnUser, ClientVersion, PSVersion, PSBuild, Sitecode, Domain, MaxLogSize, MaxLogHistory, CacheSize, ClientCertificate, ProvisioningMode, DNS, Drivers, Updates, PendingReboot, LastBootTime, OSDiskFreeSpace, Services, AdminShare, StateMessages, WUAHandler, WMI, HWInventory, Version, $q20 Timestamp)
            VALUES ('"+$log.Hostname+"', '"+$log.Operatingsystem+"', '"+$log.Architecture+"', '"+$log.Build+"', '"+$log.Manufacturer+"', '"+$log.Model+"', '"+$log.InstallDate+"', $q3 '"+$log.LastLoggedOnUser+"', '"+$log.ClientVersion+"', '"+$log.PSVersion+"', '"+$log.PSBuild+"', '"+$log.Sitecode+"', '"+$log.Domain+"', '"+$log.MaxLogSize+"', '"+$log.MaxLogHistory+"', '"+$log.CacheSize+"', '"+$log.Certificate+"', '"+$log.ProvisioningMode+"', '"+$log.DNS+"', '"+$log.Drivers+"', '"+$log.Updates+"', '"+$log.PendingReboot+"', '"+$log.LastBootTime+"', '"+$log.OSDiskFreeSpace+"', '"+$log.Services+"', '"+$log.AdminShare+"', '"+$log.StateMessages+"', '"+$log.WUAHandler+"', '"+$log.WMI+"', '"+$log.HWInventory+"', '"+$log.Version+"', $q30 '"+$smallDateTime+"')
        end
        commit tran"

        try {
            Invoke-SqlCmd2 -ServerInstance $SQLServer -Database $Database -Query $query
        } catch {
            $ErrorMessage = $_.Exception.Message
            $text = "Error updating SQL with the following query: $transactSQL. Error: $ErrorMessage"
            Write-Error $text
        }
    }
        
    Function Update-LogFile {
        Param([Parameter(Mandatory=$true)]$Log)
        # Start the logfile
        Start-ConfigMgrHealth
        $text = $log | Select-Object Hostname, Operatingsystem, Architecture, Build, Model, InstallDate, OSUpdates, LastLoggedOnUser, ClientVersion, PSVersion, PSBuild, SiteCode, Domain, MaxLogSize, MaxLogHistory, CacheSize, Certificate, ProvisioningMode, DNS, PendingReboot, LastBootTime, OSDiskFreeSpace, Services, AdminShare, StateMessages, WUAHandler, WMI, ClientInstalled, Version, Timestamp, HWInventory | Out-String
        $text = $text.replace("`t","")
        $text = $text.replace("  ","")
        $text = $text.replace(" :",":")
        Out-LogFile -Xml $xml -Text $text
        Stop-ConfigMgrHealth
    }
    
    #endregion

    # Set default restart values to false
    $newinstall = $false
    $restartCCMExec = $false
    $Reinstall = $false

    # Build the ConfigMgr Client Install Property string
    $propertyString = ""

    foreach ($property in $Xml.Configuration.ClientInstallProperty) {
        $propertyString = $propertyString + $property
        $propertyString = $propertyString + ' '
    }
    $clientCacheSize = Get-XMLConfigClientCache
    $clientInstallProperties = $propertyString + "SMSCACHESIZE=$clientCacheSize"
    $clientAutoUpgrade = (Get-XMLConfigClientAutoUpgrade).ToLower()
    $WMI = Get-XMLConfigRemediationWMI
    $AdminShare = Get-XMLConfigRemediationAdminShare
    $ClientProvisioningMode = Get-XMLConfigRemediationClientProvisioningMode
    $ClientStateMessages = Get-XMLConfigRemediationClientStateMessages
    $ClientWUAHandler = Get-XMLConfigRemediationClientWUAHandler
    $LogShare = Get-XMLConfigLoggingShare

}

Process {
    #Start-ConfigMgrHealth
    # Veriy script is running with administrative priveleges.
    If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))
    {
        $text = 'ERROR: Powershell not running as Administrator!'
        Out-LogFile -Xml $Xml -Text $text
        Write-Error $text
        Exit 1
    }

    $FileLogging = ((Get-XMLConfigLoggingEnable).ToString()).ToLower()
    $SQLLogging = ((Get-XMLConfigSQLLoggingEnable).ToString()).ToLower()

    # Create the log object containing the result of health check
    $Log = New-LogObject

    Write-Verbose 'Testing SQL Server connection'
    if (($SQLLogging -like 'true') -and ((Test-SQLConnection) -eq $false)) {
        # Failed to create SQL connection. Logging this error to fileshare and aborting script.
        #Exit 1
    }

    Write-Verbose 'Validating WMI is not corrupt...'
    if ($WMI -like 'True') {
        Write-Verbose 'Checking if WMI is corrupt. Will reinstall configmgr client if WMI is rebuilt.'
        if ((Test-WMI -log $Log) -eq $true) {
            $reinstall = $true
        }
    }

    Write-Verbose 'Testing if ConfigMgr client is installed. Installing if not.'
    Test-ConfigMgrClient

    Write-Verbose 'Validating if ConfigMgr client is running the minimum version...'
    if ((Test-ClientVersion -Log $log) -eq $true) {
        if ($clientAutoUpgrade -like 'true') {
        $reinstall = $true
        }
    }

    Write-Verbose 'Validating services...'
    Test-Services -Xml $Xml -log $log

    # Enforce ConfigMgr agent is running
    $ccmservice = Get-Service -Name CcmExec -ErrorAction SilentlyContinue
    if ($ccmservice.Status -ne 'Running') {
        try {
            Start-Service -Name CcmExec
            Start-Sleep -Seconds 2
        }
        catch {}
    }

    Write-Verbose 'Validating ConfigMgr SiteCode...'
    if ((Test-ClientSiteCode -Xml $xml) -eq $true) {
        $reinstall = $true
    }

    Write-Verbose 'Validating client cache size. Will restart configmgr client if cache size is changed'    
    if ((Test-ClientCacheSize -Xml $xml) -eq $true) {
        $restartCCMExec = $true
    }
    

    if ((Get-XMLConfigClientMaxLogSizeEnabled -like 'True') -eq $true) {
        Write-Verbose 'Validating Max CCMClient Log Size...'
        if ((Test-ClientLogSize -Xml $xml) -eq $true) {
            $restartCCMExec = $true
        }
    }

    Write-Verbose 'Validating CCMClient provisioning mode...'
    if (($ClientProvisioningMode -like 'True') -eq $true) {
        Test-ProvisioningMode -log $log
    }
    Write-Verbose 'Validating CCMClient certificate...'

    if ((Get-XMLConfigRemediationClientCertificate - like 'True') -eq $true) {
        Test-CCMCertificateError
    }

    if (Get-XMLConfigHardwareInventoryEnable -like 'True') {
        Test-SCCMHardwareInventoryScan -Log $log
    }

    Write-Verbose 'Validating DNS...'
    if ((Get-XMLConfigDNSCheck -like 'True' ) -eq $true) {
        Test-DNSConfiguration -Log $log
    }

    Write-Verbose 'Validating Windows Update Scan not broken by bad group policy...'
    if (($ClientWUAHandler -like 'True') -eq $true) {
        Test-RegistryPol -log $log
    }

    Write-Verbose 'Validating that CCMClient is sending state messages...'
    if (($ClientStateMessages -like 'True') -eq $true) {
        Test-UpdateStore -log $log
    }

    Write-Verbose 'Validating Admin$ and C$ are shared...'
    if (($AdminShare -like 'True') -eq $true) {
        Test-AdminShare -log $log
    }

    # Disable for production
    Write-Verbose 'Testing that all devices have functional drivers.'
    if ((Get-XMLConfigDrivers -like 'True') -eq $true) {
        Test-MissingDrivers -Log $log
    }
    Write-Verbose 'Validating required updates are installed...'
    Test-Update -Log $log
    Write-Verbose 'Validating C: free diskspace (Only warning, no remediation)...'
    Test-DiskSpace

    Write-Verbose 'Getting install date of last OS patch for SQL log'
    Get-LastInstalledPatches -Log $log
    Write-Verbose 'Sending unsent state messages if any'
    Get-SCCMPolicySendUnsentStateMessages
    Write-Verbose 'Getting Source Update Message policy and policy to trigger scan update source'

    if ($newinstall -eq $false) {
        Get-SCCMPolicySourceUpdateMessage
        Get-SCCMPolicyScanUpdateSource
        Get-SCCMPolicySendUnsentStateMessages
    }
    Get-SCCMPolicyMachineEvaluation

    # Restart ConfigMgr client if tagged for restart and no reinstall tag
    if (($restartCCMExec -eq $true) -and ($Reinstall -eq $false)) {
        Write-Output "Restarting service CcmExec..."
        Restart-Service -Name CcmExec
    }

    # Updating SQL Log object with current version number
    $log.Version = $Version

    Write-Verbose 'Cleaning up after healthcheck'
    CleanUp
    Write-Verbose 'Validating pending reboot...'
    Test-PendingReboot -log $log
    Write-Verbose 'Getting last reboot time'
    Get-LastReboot -Xml $xml

    # Reinstall client if tagged for reinstall and configmgr client is not already installing
    $proc = Get-Process ccmsetup -ErrorAction SilentlyContinue
    if (($Reinstall -eq $true) -and ($null -eq $proc)) {
        Write-Verbose 'Reinstalling ConfigMgr Client'
        Resolve-Client -Xml $Xml -ClientInstallProperties $ClientInstallProperties
        # Add smalldate timestamp in SQL for when client was installed by Client Health.
        $log.ClientInstalled = Get-SmallDateTime
    }
}

End {
    # Update database and logfile with results
    if ($SQLLogging -like 'true') {
        Write-Output 'Updating SQL with results' 
        Update-SQL -Log $log
    }

    if ($FileLogging -like 'true') {
        Write-Output 'Updating logfile with results' 
        Update-LogFile -Log $log
    }
}