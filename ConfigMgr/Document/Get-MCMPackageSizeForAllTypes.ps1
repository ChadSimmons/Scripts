#.Synopsis
#  Get details for each Content type for analysis on size and in-use status
#.Notes
#  === History ===
#  2016/07/06 Chad.Simmons@CatapultSystems.com - created
#  === To Do ===
#  Applications / Deployment Types are not addressed
#  Drivers (not Driver Packages) are not addressed
#  Extended data not addressed: DPCount, IsDeployedOrReferenced, ContentTotal, ContentSuperseded, ContentExpired

$SiteCode = "LAB"
$ReportFile = 'D:\Temp\Get-CMPackageSizeForAllTypes.csv'

#Load Configuration Manager PowerShell Module
#.Link http://blogs.technet.com/b/configmgrdogs/archive/2015/01/05/powershell-ise-add-on-to-connect-to-configmgr-connect-configmgr.aspx
If ($null -ne $Env:SMS_ADMIN_UI_PATH) {
	Try {
		Write-Host "Importing ConfigMgr PowerShell Module..."
		Import-Module ((Split-Path $env:SMS_ADMIN_UI_PATH)+"\ConfigurationManager.psd1")
		## Another method ## Import-Module $env:SMS_ADMIN_UI_PATH.Replace("\bin\i386","\bin\ConfigurationManager.psd1")
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

Push-Location "$SiteCode`:"

#Get Applications
#SELECT DISTINCT app.Manufacturer, app.DisplayName, app.SoftwareVersion, dt.DisplayName [DeploymentTypeName], dt.PriorityInLatestApp, dt.Technology, v_ContentInfo.ContentSource, v_ContentInfo.SourceSize [SizeInKB]
#FROM dbo.fn_ListDeploymentTypeCIs(1033) AS dt
#INNER JOIN dbo.fn_ListLatestApplicationCIs(1033) AS app ON dt.AppModelName = app.ModelName
#LEFT OUTER JOIN v_ContentInfo ON dt.ContentId = v_ContentInfo.Content_UniqueID
#WHERE dt.IsLatest = 1

$CombinedPackages = @()

$MyPackages = @(Get-CMApplication | Where-Object { $_.IsLatest -eq $true}) # | Select Manufacturer, LocalizedDisplayName, SoftwareVersion, HasContent, IsDeployed, IsEnabled, IsLatest, IsSuperseded, SDMPackageXML
$MyPackages | Add-Member -MemberType NoteProperty -Name Type -Value 'Application'
$MyPackages | Add-Member -MemberType NoteProperty -Name MBTotal -Value $null
$MyPackages | Add-Member -MemberType NoteProperty -Name DPCount -Value $null
$MyPackages | Add-Member -MemberType NoteProperty -Name IsDeployedOrReferenced -Value $null
$MyPackages | Add-Member -MemberType NoteProperty -Name ContentTotal -Value $null
$MyPackages | Add-Member -MemberType NoteProperty -Name ContentSuperseded -Value 0
$MyPackages | Add-Member -MemberType NoteProperty -Name ContentExpired -Value 0
$MyPackages | Add-Member -MemberType NoteProperty -Name FullName -Value $null
$MyPackages | Add-Member -MemberType NoteProperty -Name Name -Value $null
$MyPackages | Add-Member -MemberType NoteProperty -Name PkgSourcePath -Value $null
$MyPackages | ForEach-Object {
    $_.FullName = $_.Manufacturer
    $_.FullName = $_.FullName+" "+$_.LocalizedDisplayName
    $_.FullName = ($_.FullName+" "+$_.SoftwareVersion).Trim()
    $_.Name = $_.FullName
    #$_.ContentTotal = ((([xml]($MyPackages.SDMPackageXML)).AppMgmtDigest[0].DeploymentType)).count
}
#$MyPackages | Get-Member -MemberType Property
#$MyPackages | Select Type, PackageID, MBTotal, Name, ContentTotal, ContentSuperseded, ContentExpired, IsDeployedOrReferenced, DPCount, PkgSourcePath | Format-Table -AutoSize
$CombinedPackages += $MyPackages | Select-Object Type, PackageID, MBTotal, Name, ContentTotal, ContentSuperseded, ContentExpired, IsDeployedOrReferenced, DPCount, PkgSourcePath

#$MyPackages = $MyPackages | Where { $_.LocalizedDisplayName -eq 'Java 7 Update 55'}

#.Link for reference https://david-obrien.net/2013/04/set-cmdeploymenttype-via-powershell-for-configmgr-2012/
#([xml]($MyPackages.SDMPackageXML)).AppMgmtDigest.DeploymentType.Installer.Contents.Content.Location
#([xml]($MyPackages.SDMPackageXML)).AppMgmtDigest.DeploymentType.Title
#([Microsoft.ConfigurationManagement.ApplicationManagement.Serialization.SccmSerializer]::DeserializeFromString($MyPackages.SDMPackageXML)).DeploymentTypes[0].Contents
ForEach ($MyPackage in ($MyPackages | Where-Object { $_.HasContent -eq $true})) {
    ForEach ($DeploymentType in (([xml]($MyPackage.SDMPackageXML)).AppMgmtDigest.DeploymentType)) {
        $ThisPackage = $MyPackage.Clone()
        $ThisPackage | Add-Member -MemberType NoteProperty -Name Type -Value 'Application Deployment'
        $ThisPackage | Add-Member -MemberType NoteProperty -Name MBTotal -Value $null
        $ThisPackage | Add-Member -MemberType NoteProperty -Name DPCount -Value $null
        $ThisPackage | Add-Member -MemberType NoteProperty -Name IsDeployedOrReferenced -Value $null
        $ThisPackage | Add-Member -MemberType NoteProperty -Name ContentTotal -Value $null
        $ThisPackage | Add-Member -MemberType NoteProperty -Name ContentSuperseded -Value $null
        $ThisPackage | Add-Member -MemberType NoteProperty -Name ContentExpired -Value $null
        $ThisPackage | Add-Member -MemberType NoteProperty -Name FullName -Value $MyPackage.FullName
        $ThisPackage | Add-Member -MemberType NoteProperty -Name Name -Value $MyPackage.Name
        $ThisPackage | Add-Member -MemberType NoteProperty -Name PkgSourcePath -Value $DeploymentType.Installer.Contents.Content.Location

        #$ThisPackage | Get-Member
        #$MyPackage | Get-Member

        $ThisPackage.FullName += " -> $($DeploymentType.Title.'#text')"
        $ThisPackage.Name = $ThisPackage.FullName
        $ThisPackage.MBTotal = 0
        ForEach ($ContentFile in $($DeploymentType.Installer.Contents.Content.File)) { $ThisPackage.MBTotal += [int]$ContentFile.Size }
        $ThisPackage.MBTotal = [math]::Round($ThisPackage.MBTotal/1024/1024,1)
        #$DeploymentType | Get-Member
        #$ThisPackage | Select PackageID, Name, PackageSize, LastRefreshTime, PkgSourcePath, Type, MBTotal, ContentTotal, ContentSuperseded, ContentExpired, IsDeployedOrReferenced, DPCount
        $CombinedPackages += $ThisPackage | Select-Object PackageID, Name, PackageSize, LastRefreshTime, PkgSourcePath, Type, MBTotal, ContentTotal, ContentSuperseded, ContentExpired, IsDeployedOrReferenced, DPCount
    }
}


#Get standard Software Packages
$MyPackages = @(Get-CMPackage | Select-Object PackageID, Name, PackageSize, LastRefreshTime, Manufacturer, Version, PkgSourcePath)
$MyPackages | Add-Member -MemberType NoteProperty -Name Type -Value 'Package'
$MyPackages | Add-Member -MemberType NoteProperty -Name MBTotal -Value $null
$MyPackages | Add-Member -MemberType NoteProperty -Name DPCount -Value $null
$MyPackages | Add-Member -MemberType NoteProperty -Name IsDeployedOrReferenced -Value $null
$MyPackages | Add-Member -MemberType NoteProperty -Name ContentTotal -Value 1
$MyPackages | Add-Member -MemberType NoteProperty -Name ContentSuperseded -Value 0
$MyPackages | Add-Member -MemberType NoteProperty -Name ContentExpired -Value 0
$MyPackages | Add-Member -MemberType NoteProperty -Name FullName -Value $null
$MyPackages | ForEach-Object {
    $_.MBTotal = [math]::Round($_.PackageSize/2014,1)
    $_.FullName = $_.Manufacturer
    $_.FullName = $_.FullName+" "+$_.Name
    $_.FullName = ($_.FullName+" "+$_.Version).Trim()
    $_.Name = $_.FullName
}
$CombinedPackages += $MyPackages

#Get Software Update Packages
$MyPackages = @(Get-CMSoftwareUpdateDeploymentPackage | Select-Object PackageID, Name, PackageSize, LastRefreshTime, PkgSourcePath)
$MyPackages | Add-Member -MemberType NoteProperty -Name Type -Value 'Software Updates'
$MyPackages | Add-Member -MemberType NoteProperty -Name MBTotal -Value $null
$MyPackages | Add-Member -MemberType NoteProperty -Name DPCount -Value $null
$MyPackages | Add-Member -MemberType NoteProperty -Name IsDeployedOrReferenced -Value $null
$MyPackages | Add-Member -MemberType NoteProperty -Name ContentTotal -Value $null
$MyPackages | Add-Member -MemberType NoteProperty -Name ContentSuperseded -Value $null
$MyPackages | Add-Member -MemberType NoteProperty -Name ContentExpired -Value $null
$MyPackages | ForEach-Object { $_.MBTotal = [math]::Round($_.PackageSize/1024,1) }
$CombinedPackages += $MyPackages

#Get Drivers


#Get Driver Packages
$MyPackages = @(Get-CMDriverPackage | Select-Object PackageID, Name, PackageSize, LastRefreshTime, PkgSourcePath)
$MyPackages | Add-Member -MemberType NoteProperty -Name Type -Value 'Drivers'
$MyPackages | Add-Member -MemberType NoteProperty -Name MBTotal -Value $null
$MyPackages | Add-Member -MemberType NoteProperty -Name DPCount -Value $null
$MyPackages | Add-Member -MemberType NoteProperty -Name IsDeployedOrReferenced -Value $null
$MyPackages | Add-Member -MemberType NoteProperty -Name ContentTotal -Value $null
$MyPackages | Add-Member -MemberType NoteProperty -Name ContentSuperseded -Value 0
$MyPackages | Add-Member -MemberType NoteProperty -Name ContentExpired -Value 0
$MyPackages | ForEach-Object { $_.MBTotal = [math]::Round($_.PackageSize/1024,1) }
$CombinedPackages += $MyPackages

#Get Operating System Image Packages
$MyPackages = @(Get-CMOperatingSystemImage | Select-Object PackageID, Name, PackageSize, LastRefreshTime, PkgSourcePath)
$MyPackages | Add-Member -MemberType NoteProperty -Name Type -Value 'OS Image'
$MyPackages | Add-Member -MemberType NoteProperty -Name MBTotal -Value $null
$MyPackages | Add-Member -MemberType NoteProperty -Name DPCount -Value $null
$MyPackages | Add-Member -MemberType NoteProperty -Name IsDeployedOrReferenced -Value $null
$MyPackages | Add-Member -MemberType NoteProperty -Name ContentTotal -Value 1
$MyPackages | Add-Member -MemberType NoteProperty -Name ContentSuperseded -Value 0
$MyPackages | Add-Member -MemberType NoteProperty -Name ContentExpired -Value 0
$MyPackages | ForEach-Object { $_.MBTotal = [math]::Round($_.PackageSize/1024,1) }
$CombinedPackages += $MyPackages

#Get Operating System Installer Packages
$MyPackages = @(Get-CMOperatingSystemInstaller | Select-Object PackageID, Name, PackageSize, LastRefreshTime, PkgSourcePath)
$MyPackages | Add-Member -MemberType NoteProperty -Name Type -Value 'OS Installer'
$MyPackages | Add-Member -MemberType NoteProperty -Name MBTotal -Value $null
$MyPackages | Add-Member -MemberType NoteProperty -Name DPCount -Value $null
$MyPackages | Add-Member -MemberType NoteProperty -Name IsDeployedOrReferenced -Value $null
$MyPackages | Add-Member -MemberType NoteProperty -Name ContentTotal -Value 1
$MyPackages | Add-Member -MemberType NoteProperty -Name ContentSuperseded -Value 0
$MyPackages | Add-Member -MemberType NoteProperty -Name ContentExpired -Value 0
$MyPackages | ForEach-Object { $_.MBTotal = [math]::Round($_.PackageSize/1024,1) }
$CombinedPackages += $MyPackages

#Get Boot Images Packages
$MyPackages = @(Get-CMBootImage | Select-Object PackageID, Name, PackageSize, LastRefreshTime, PkgSourcePath)
$MyPackages | Add-Member -MemberType NoteProperty -Name Type -Value 'Boot Image'
$MyPackages | Add-Member -MemberType NoteProperty -Name MBTotal -Value $null
$MyPackages | Add-Member -MemberType NoteProperty -Name DPCount -Value $null
$MyPackages | Add-Member -MemberType NoteProperty -Name IsDeployedOrReferenced -Value $null
$MyPackages | Add-Member -MemberType NoteProperty -Name ContentTotal -Value 1
$MyPackages | Add-Member -MemberType NoteProperty -Name ContentSuperseded -Value 0
$MyPackages | Add-Member -MemberType NoteProperty -Name ContentExpired -Value 0
$MyPackages | ForEach-Object { $_.MBTotal = [math]::Round($_.PackageSize/1024,1) }
$CombinedPackages += $MyPackages

#Get Virtual Hard Disks
$MyPackages = @(Get-CMvhd | Select-Object PackageID, Name, PackageSize, LastRefreshTime, PkgSourcePath)
$MyPackages | Add-Member -MemberType NoteProperty -Name Type -Value 'Virtual Hard Disks'
$MyPackages | Add-Member -MemberType NoteProperty -Name MBTotal -Value $null
$MyPackages | Add-Member -MemberType NoteProperty -Name DPCount -Value $null
$MyPackages | Add-Member -MemberType NoteProperty -Name IsDeployedOrReferenced -Value $null
$MyPackages | Add-Member -MemberType NoteProperty -Name ContentTotal -Value 1
$MyPackages | Add-Member -MemberType NoteProperty -Name ContentSuperseded -Value 0
$MyPackages | Add-Member -MemberType NoteProperty -Name ContentExpired -Value 0
$MyPackages | ForEach-Object { $_.MBTotal = [math]::Round($_.PackageSize/1024,1) }
$CombinedPackages += $MyPackages

#$CombinedPackages += $MyPackages | Select PackageID, Name, PackageSize, LastRefreshTime, PkgSourcePath, Type, MBTotal, ContentTotal, ContentSuperseded, ContentExpired, IsDeployedOrReferenced, DPCount

$CombinedPackages | Select-Object Type, PackageID, MBTotal, Name, LastRefreshTime, ContentTotal, ContentSuperseded, ContentExpired, IsDeployedOrReferenced, DPCount, PkgSourcePath | Export-CSV -Path $ReportFile -NoTypeInformation
$CombinedPackages | Sort-Object PackageSize | Select-Object Type, PackageID, MBTotal, Name, LastRefreshTime, ContentTotal, ContentSuperseded, ContentExpired, IsDeployedOrReferenced, DPCount, PkgSourcePath | Format-Table -AutoSize

Pop-Location