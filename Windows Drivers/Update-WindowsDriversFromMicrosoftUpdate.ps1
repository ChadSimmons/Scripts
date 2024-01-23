#http://rzander.azurewebsites.net/script-to-install-or-update-drivers-directly-from-microsoft-catalog/
$UpdateSvc = New-Object -ComObject Microsoft.Update.ServiceManager
$UpdateSvc.AddService2("7971f918-a847-4430-9279-4a52d1efe18d",7,"")

(New-Object -ComObject Microsoft.Update.ServiceManager).Services

$Session = New-Object -ComObject Microsoft.Update.Session
$Searcher = $Session.CreateUpdateSearcher()

$Searcher.ServiceID = '7971f918-a847-4430-9279-4a52d1efe18d'
$Searcher.SearchScope =  1 # MachineOnly
$Searcher.ServerSelection = 3 # Third Party
$Criteria = "IsInstalled=0 and Type='Driver'"

Write-Host('Searching Driver-Updates...') -Fore Green
$SearchResult = $Searcher.Search($Criteria)
$Updates = $SearchResult.Updates

$Exclude = @('ThinkPad P50 System Firmware 1.48')
$Updates = $Updates | Where-Object { $_.DriverModel -notin $Exclude }
#Show available Drivers...
$Updates | Select-Object DriverModel, Title, DriverVerDate, DriverClass, DriverManufacturer | Sort-Object DriverModel, Title | Format-Table -AutoSize
$Updates.Count

$UpdatesToDownload = New-Object -Com Microsoft.Update.UpdateColl
$updates | ForEach-Object { $UpdatesToDownload.Add($_) | out-null }
Write-Host('Downloading Drivers...')  -Fore Green
$UpdateSession = New-Object -Com Microsoft.Update.Session
$Downloader = $UpdateSession.CreateUpdateDownloader()
$Downloader.Updates = $UpdatesToDownload
$Downloader.Download()

$UpdatesToInstall = New-Object -Com Microsoft.Update.UpdateColl
$updates | ForEach-Object { if($_.IsDownloaded) { $UpdatesToInstall.Add($_) | out-null } }

Write-Host('Installing Drivers...')  -Fore Green
$Installer = $UpdateSession.CreateUpdateInstaller()
$Installer.Updates = $UpdatesToInstall
$InstallationResult = $Installer.Install()
If ($InstallationResult.RebootRequired) {
	Write-Host('Reboot required! please reboot now..') -ForegroundColor Red
} else { Write-Host('Done') -ForegroundColor Green }
