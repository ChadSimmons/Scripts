$AllPackages = Get-CMSoftwareUpdateDeploymentPackage
$MyPackages = $AllPackages | Select PackageID, Name, PackageSize, LastRefreshTime, PkgSourcePath
$MyPackages | Add-Member -MemberType NoteProperty -Name MBTotal -Value $null
#$MyPackages | Add-Member -MemberType NoteProperty -Name UpdatesTotal -Value $null
#$MyPackages | Add-Member -MemberType NoteProperty -Name UpdatesSupserseded -Value $null
#$MyPackages | Add-Member -MemberType NoteProperty -Name UpdatesExpired -Value $null
$MyPackages | ForEach { $_.MBTotal = [math]::Round($_.PackageSize/2014,1) }
$MyPackages | Export-CSV -Path "ConfigMgr Software Update Deployment Packages.csv" -NoTypeInformation
$MyPackages | Sort-Object PackageSize | Select PackageID, MBTotal, Name, LastRefreshTime | Format-Table -AutoSize
