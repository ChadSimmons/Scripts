#.Synopsis
#	Uninstall any Microsoft Hotfix / KB / Patch / Update installed in the last 1 day that is detectable by Get-Hotfix
#.Note
#	https://rsr72.wordpress.com/2012/07/23/uninstall-microsoft-hotfixes-with-powershell/
#	http://techibee.com/powershell/powershell-uninstall-windows-hotfixesupdates/1084

$Hotfixes = Get-HotFix Select-Object CSName, HotFixID, Description, InstalledBy, InstalledOn, @{Name = 'InventoriedOn'; Expression = { $(Get-Date) } }
$HotfixesInstalledRecently = @(Get-HotFix | Where-Object InstalledOn -GE (Get-Date).AddDays(-1))
$Hotfixes | Sort-Object InstalledOn | Out-GridView #Format-Table -AutoSize
$Hotfixes | Sort-Object InstalledOn | Export-CSV -Path "$env:SystemRoot\Logs\Hotfixes Installed.csv" -Append -NoTypeInformation
ForEach ($Hotfix in $HotfixesInstalledRecently) {
    $i += 1
    Write-Output "Uninstalling ($($Hotfix).HotFixID)"
    If ($i -ne $(($HotfixesInstalledRecently).Count)) {
        Start-Process -FilePath 'wusa.exe' -ArgumentList "/uninstall /kb:$(($hotfix).HotFixID -replace 'KB','') /quiet /norestart"
        While (@(Get-Process wusa -ErrorAction SilentlyContinue).Count -ne 0) {
            Start-Sleep 3
            Write-Host "Waiting for update removal to finish ..."
        }
    } else {
        Start-Process -FilePath 'wusa.exe' -ArgumentList "/uninstall /kb:$(($hotfix).HotFixID -replace 'KB','') /quiet /promptrestart"
    }
}
#Write-Output "Completed the uninstallation of $(($Hotfixes).Count) hotfixes"