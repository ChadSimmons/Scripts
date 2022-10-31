$PackageIDsFile = "$env:UserProfile\Documents\PackageIDs.txt"
$PackageIDs = Import-CSV -Path $PackageIDsFile -Header 'PackageID'
$PackageIDs | Add-Member -MemberType NoteProperty -Name PackageSize -Value $null
$PackageIDs | Add-Member -MemberType NoteProperty -Name PackageFullName -Value $null
$PackageIDs | Add-Member -MemberType NoteProperty -Name LastUpdated -Value $null
$PackageIDs | Get-Member
#$PackageIDs = $PackageIDs | Select -First 5
#$PackageIDs | Select -First 2 | Format-Table -AutoSize

If ($PackageIDs.count -gt 50 -and $AllPackages.count -eq 0) { $AllPackages = Get-CMPackage }

ForEach ($Package in $PackageIDs) {
    If ($AllPackages.count -le 1) {
            $AllPackages = Get-CMPackage -ID $Package.PackageID
    }
    $CurrentPackage = ($AllPackages | Where-Object { $_.PackageID -eq $Package.PackageID })
    $Package.PackageSize = ($CurrentPackage).PackageSize
    $Package.PackageFullName = ($CurrentPackage).Manufacturer
    $Package.PackageFullName = $Package.PackageFullName+" "+($CurrentPackage).Name
    $Package.PackageFullName = $Package.PackageFullName+" "+($CurrentPackage).Version
    $Package.PackageFullName = $Package.PackageFullName.Trim()
    $Package.LastUpdated = ($CurrentPackage).LastRefreshTime
}

$PackageIDs | Export-CSV -Path "$PackageIDsFile.csv" -NoTypeInformation
$PackageIDs | Sort-Object PackageSize | Format-Table -AutoSize
