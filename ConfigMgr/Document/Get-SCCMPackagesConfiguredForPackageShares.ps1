#.Synopsis
#  Get all ConfigMgr Packages which are Share enabled
#.Description
#  These packages have the setting "Copy the content in this package to a package share on distribution points" enabled
#.Link
# How To: List Packages that are Configured to use a Package Share in ConfigMgr 2012
# https://gregramsey.net/2013/02/14/how-to-list-packages-that-are-configured-to-use-a-package-share-in-configmgr-2012/
#.Notes
# http://myitforum.com/myitforumwp/2011/10/21/sccm-flags-updated-advertflags-boundaryflags-deviceflags-imageflags-offerflags-pkgflags-programflags-referenceimageflags-remoteclientflags-timeflags-ts_flags/
# PkgFlags on MSDN https://msdn.microsoft.com/en-us/library/hh948196.aspx
# https://msdn.microsoft.com/en-us/library/cc146062.aspx


#Load Configuration Manager PowerShell Module
#.Link http://blogs.technet.com/b/configmgrdogs/archive/2015/01/05/powershell-ise-add-on-to-connect-to-configmgr-connect-configmgr.aspx
If ($Env:SMS_ADMIN_UI_PATH -ne $null) {
	Try {
		Write-Host "Importing ConfigMgr PowerShell Module..."
		Import-Module ((Split-Path $env:SMS_ADMIN_UI_PATH)+"\ConfigurationManager.psd1")
		## Another method ## Import-Module $env:SMS_ADMIN_UI_PATH.Replace("\bin\i386","\bin\configurationmanager.psd1")
		## Another method ## Import-module ($Env:SMS_ADMIN_UI_PATH.Substring(0,$Env:SMS_ADMIN_UI_PATH.Length-5) + '\ConfigurationManager.psd1')
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


$Packages = Get-CMPackage | Where { $_.pkgflags -eq ($_.pkgflags -bor 0x80) } #80 hex is 128 decimal
$Packages | Select PackageID, Manufacturer, Name, Version, LastRefreshTime, PackageSize, PkgFlags, ShareName

