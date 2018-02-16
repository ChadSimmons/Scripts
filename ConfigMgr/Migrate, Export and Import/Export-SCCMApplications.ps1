$ExportPath = '\\Lab-CM1\Source\Export'
$SiteCode = 'LAB'

$MyLocation = Get-Location

Set-Location "$env:UserProfile"
If (-not(Test-Path -Path "$ExportPath\Apps")) { New-Item -Path "$ExportPath" -Name 'Apps' -ItemType Directory -ErrorAction SilentlyContinue }
Set-Location "$SiteCode`:\"
$Apps = Get-CMApplication
$i = 0
ForEach ($App in $Apps) {
	$i++
	Write-Progress -Activity "Exporting ConfigMgr Applications" -Status "[$i of $($Apps.Count)] $($App.Manufacturer) $($App.LocalizedDisplayName) $($App.SoftwareVersion)" -PercentComplete $($($i / $($Apps.Count)) * 100)
	Write-Output "Exporting ConfigMgr Application $i of $($Apps.Count) : $($App.Manufacturer) $($App.LocalizedDisplayName) $($App.SoftwareVersion)".Trim()
	$ExportFile = "$ExportPath\Apps\App.$($App.Manufacturer)_$($App.LocalizedDisplayName)_$($App.SoftwareVersion).zip"
	Set-Location "$env:UserProfile"
	If (Test-Path -Path $ExportFile) {
		Remove-Item -Path "$ExportFile" -Force
	}
	Set-Location "$SiteCode`:\"
	Export-CMApplication -InputObject $App -Path "$ExportFile" -Comment $("$($App.Manufacturer) $($App.LocalizedDisplayName) $($App.SoftwareVersion)".Trim()) -OmitContent #-IgnoreRelated
}

Set-Location "$env:UserProfile"
#region Create Zip archive file
Add-Type -Assembly System.IO.Compression.FileSystem
$archiveFile = "$ExportPath\Apps.$(Get-Date -format 'yyyyMMdd_HHmm').zip"
[System.IO.Compression.ZipFile]::CreateFromDirectory("$ExportPath\Apps", $archiveFile, $([System.IO.Compression.CompressionLevel]::Optimal), $false)
#endregion

Set-Location $MyLocation
