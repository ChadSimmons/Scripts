#Load Configuration Manager PowerShell Module
#.Link http://blogs.technet.com/b/configmgrdogs/archive/2015/01/05/powershell-ise-add-on-to-connect-to-configmgr-connect-configmgr.aspx
If ($null -ne $Env:SMS_ADMIN_UI_PATH) {
	Try {
		Write-Host "Importing ConfigMgr PowerShell Module..."
		Import-Module ((Split-Path $env:SMS_ADMIN_UI_PATH)+"\ConfigurationManager.psd1")
		Write-Host "Executed `"Import-module `'((Split-Path $env:SMS_ADMIN_UI_PATH)+"\ConfigurationManager.psd1")`'`""
        $SiteCode = (Get-PSDrive -PSProvider CMSITE).Name
		Push-Location "$($SiteCode):\"
		#Dir
		Pop-Location
        Write-Host "Detected ConfigMgr Site of $SiteCode.  Execute the command 'CD $($SiteCode):\' before running any ConfigMgr cmdlet" -ForegroundColor Green
	} Catch {
		Write-Error "Executing `"Import-module `'((Split-Path $env:SMS_ADMIN_UI_PATH)+"\ConfigurationManager.psd1")`'`""
	}
}

Function Get-RegistryValues($key) { (Get-Item $key).GetValueNames() } #.Example   Get-RegistryValues HKLM:\Software\Microsoft\Windows\CurrentVersion
Function Get-RegistryValue($key, $value) { (Get-ItemProperty $key $value).$value } #.Example Get-RegistryValue 'HKLM:\Software\Microsoft\Windows NT\CurrentVersion' RegisteredOwner
Function Test-IsProcElevatedAdmin {[bool](([System.Security.Principal.WindowsIdentity]::GetCurrent()).groups -match 'S-1-5-32-544')}
Function Test-IsAdminByRole {([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]'Administrator')} #http://blogs.technet.com/b/heyscriptingguy/archive/2011/05/11/check-for-admin-credentials-in-a-powershell-script.aspx
(Get-Host).UI.RawUI.WindowTitle = "Windows PowerShell version $($PSVersionTable.PSVersion.ToString()) :: running as $env:USERDOMAIN\$env:USERNAME ($env:USERDNSDOMAIN)"
If (Test-IsProcElevatedAdmin) { (Get-Host).UI.RawUI.WindowTitle = "$((Get-Host).UI.RawUI.WindowTitle) with elevated rights" }
Clear
"`nBitness:$env:Processor_architecture || PoSH Version:$($PSVersionTable.PSVersion.ToString()) || ExecutionPolicy:$(Get-ExecutionPolicy) || isAdmin:$(Test-IsProcElevatedAdmin)/$(Test-IsAdminByRole) || RunAs:$($env:USERDOMAIN)\$($env:USERNAME) ($env:USERDNSDOMAIN)"
If([bool]!([Environment]::GetCommandLineArgs() -like '-NoProfile')) {write-host "Profile:$profile"} else {"Profile was Used:False"}
"Command Line Args: $([Environment]::GetCommandLineArgs())"
Write-Host $('='*(($([Environment]::GetCommandLineArgs())).length+19)) -ForegroundColor White -BackgroundColor DarkGreen
If ($null -ne $Env:SMS_ADMIN_UI_PATH) { Write-Host "Detected ConfigMgr Site of $SiteCode.  Execute the command 'CD $($SiteCode):\' before running any ConfigMgr cmdlet" }
If (Test-IsProcElevatedAdmin) {
    Write-Host 'PowerShell is running with Elevated Administrative rights (Run As Administrator)'
    } else { Write-Host 'PowerShell is NOT running with Elevated Administrative rights (Run As Administrator)'
}
