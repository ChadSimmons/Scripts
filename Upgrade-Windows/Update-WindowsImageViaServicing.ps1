#.Synopsis
#   Update-WindowsImageViaServicing.ps1
#   Offline service (upgrade/update/patch) a Windows 10 / Server 2016 default image with the latest updates including the WinRE and Boot WIM files
#.Link
#   https://github.com/DeploymentResearch/DRFiles/blob/master/Scripts/Create-W10RefImageViaDISM.ps1
#   https://deploymentresearch.com/Research/Post/672/Windows-10-Servicing-Script-Creating-the-better-In-Place-upgrade-image
#.NOTES
# To service a newer version of WinPE than the OS you are servicing from, for example service Windows 10 v1709
# from a Windows Server 2016 server, you need a newer DISM version.
# Solution, simply install the latest Windows ADK 10, and use DISM from that version
#
#  URL example for Windows 10 Servicing Stack Update file: https://www.catalog.update.microsoft.com/Search.aspx?q=Update%20for%20Windows%2010%20Version%201809%20for%20x64-based%20Systems
#  URL example for Windows 10 Cumulative Update file: https://www.catalog.update.microsoft.com/Search.aspx?q=Cumulative%20Update%20for%20Windows%2010%20Version%201809%20for%20x64-based%20Systems
#  URL example for Windows 10 Adobe Flash Update file: https://www.catalog.update.microsoft.com/Search.aspx?q=Adobe%20Flash%20Player%20for%20Windows%2010%20Version%201809%20for%20x64-based%20Systems

# Windows 10 Servicing Stack Updates https://docs.microsoft.com/en-us/windows/deployment/update/servicing-stack-updates
#    Latest servicing stack updates https://portal.msrc.microsoft.com/en-us/security-guidance/advisory/ADV990001
# Windows Cumulative Updates https://support.microsoft.com/en-us/help/4480116
#    Example https://www.catalog.update.microsoft.com/Search.aspx?q=Cumulative%20Update%20for%20Windows%2010%20Version%201809%20for%20x64-based%20Systems
# .NET Framework Update
# Adobe Flash Update

# Configuring the script to use the Windows built-in version of DISM
$DISMFile = "$env:SystemRoot\System32\DISM.exe"
# Configuring the script to use the Windows ADK 10 version of DISM
# $DISMFile = 'C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\DISM\dism.exe'

# Set additional parameters
$WIMServicingFolder = 'G:\WIMServicing'
$ISO = 'G:\Source\OSD\OSInstall\SW_DVD9_Win_Pro_Ent_Edu_N_10_1809_64BIT_English_-4_MLF_X21-87129.iso'
$UpdateFolder = 'G:\Source\OSD\OSInstall\Win10x64v1809 Updates'
$ServicingUpdate = Join-Path -Path $UpdateFolder -ChildPath 'windows10.0-kb4456655-x64_fca3f0c885da48efc6f9699b0c1eaf424e779434.msu'
$MonthlyCU = Join-Path -Path $UpdateFolder -ChildPath 'windows10.0-kb4458469-v2-x64_1f4f81ab4628364d0136a708bda0ad6bde8046e7.msu'
$AdobeFlashUpdate = Join-Path -Path $UpdateFolder -ChildPath 'windows10.0-kb4457146-x64_8aff4c5fd18be7fb63f2700333c1a9c8961c8ade.msu'
$ImageMountFolder = Join-Path -Path $WIMServicingFolder -ChildPath 'Mount_Image'
$BootImageMountFolder = Join-Path -Path $WIMServicingFolder -ChildPath 'Mount_BootImage'
#$WIMImageFolder = Join-Path -Path $WIMServicingFolder -ChildPath 'WIMs'
$TmpImage = Join-Path -Path $WIMServicingFolder -ChildPath 'tmp_install.wim'
$TmpWinREImage = Join-Path -Path $WIMServicingFolder -ChildPath 'tmp_winre.wim'
$RefImage = Join-Path -Path $WIMServicingFolder -ChildPath 'install.wim'
$BootImage = Join-Path -Path $WIMServicingFolder -ChildPath 'boot.wim'

# Verify that files and folder exist
$ScriptStartTime = Get-Date
if (!(Test-Path -path $DISMFile)) {Write-Warning "DISM in Windows ADK not found, Aborting..."; Break}
if (!(Test-Path -path $ISO)) {Write-Warning "Could not find Windows 10 ISO file. Aborting..."; Break}
if (!(Test-Path -path $ServicingUpdate)) {Write-Warning "Could not find Servicing Update for Windows 10. Aborting..."; Break}
if (!(Test-Path -path $AdobeFLashUpdate)) {Write-Warning "Could not find Adobe Flash Update for Windows 10. Aborting..."; Break}
if (!(Test-Path -path $MonthlyCU)) {Write-Warning "Could not find Monthly Update for Windows 10. Aborting..."; Break}
if (!(Test-Path -path $ImageMountFolder)) {New-Item -path $ImageMountFolder -ItemType Directory}
if (!(Test-Path -path $BootImageMountFolder)) {New-Item -path $BootImageMountFolder -ItemType Directory}
#if (!(Test-Path -path $WIMImageFolder)) {New-Item -path $WIMImageFolder -ItemType Directory}
# Check Windows Version
$OSCaption = (Get-WmiObject win32_OperatingSystem).caption
#If (!($OSCaption -like "Microsoft Windows 10*" -or $OSCaption -like "Microsoft Windows Server 2016*")) {Write-Warning "$env:ComputerName oops, you really should use Windows 10 or Windows Server 2016 when servicing Windows 10 offline. Aborting...";Break}

# Mount the Windows 10 ISO
Write-Progress -Activity 'Extracting default image' -Status 'Mounting Windows ISO'
Mount-DiskImage -ImagePath $ISO
$ISOImage = Get-DiskImage -ImagePath $ISO | Get-Volume
$ISODrive = [string]$ISOImage.DriveLetter + ":"

# Mount index 2 of the Windows 10 boot image (boot.wim)
Write-Progress -Activity 'Updating boot image' -Status 'Mount index 2 of the Windows 10 boot image (boot.wim)' -CurrentOperation 'Copying'
Copy-Item "$ISODrive\Sources\boot.wim" $WIMImageFolder
Attrib -r $BootImage
Write-Progress -Activity 'Updating boot image' -Status 'Mount index 2 of the Windows 10 boot image (boot.wim)' -CurrentOperation 'Mounting'
Mount-WindowsImage -ImagePath $BootImage -Index 2 -Path $BootImageMountFolder

# Add the Updates to the boot image
Write-Progress -Activity 'Updating boot image' -Status 'Add the Updates to the image' -CurrentOperation 'Servicing Update'
& $DISMFile /Image:$BootImageMountFolder /Add-Package /PackagePath:$ServicingUpdate
Write-Progress -Activity 'Updating boot image' -Status 'Add the Updates to the image' -CurrentOperation 'Cumulative Update'
& $DISMFile /Image:$BootImageMountFolder /Add-Package /PackagePath:$MonthlyCU

# Dismount the boot image
Write-Progress -Activity 'Updating boot image' -Status 'Save and dismount the image'
DisMount-WindowsImage -Path $BootImageMountFolder -Save

# Export the Windows 10 Enterprise index to a new (temporary) WIM
Write-Progress -Activity 'Extracting default image' -Status 'Exporting the Windows 10 Enterprise index to a new (temporary) WIM'
Export-WindowsImage -SourceImagePath "$ISODrive\Sources\install.wim" -SourceName 'Windows 10 Enterprise' -DestinationImagePath $TmpImage

Write-Progress -Activity 'Cleanup' -Status 'Dismount the Windows ISO'
Dismount-DiskImage -ImagePath $ISO

# Mount the Windows 10 Enterprise image/index with the Optimize option (reduces initial mount time)
Write-Progress -Activity 'Extracting default image' -Status 'Mount the Windows 10 Enterprise image/index with the Optimize option (reduces initial mount time)'
Mount-WindowsImage -ImagePath $TmpImage -Index 1 -Path $ImageMountFolder -Optimize

# Add the Updates to the Windows 10 Enterprise image
Write-Progress -Activity 'Updating default image' -Status 'Add the Updates to the Windows image' -CurrentOperation 'Servicing Update'
& $DISMFile /Image:$ImageMountFolder /Add-Package /PackagePath:$ServicingUpdate
Write-Progress -Activity 'Updating default image' -Status 'Add the Updates to the Windows image' -CurrentOperation 'Adobe Flash Update'
& $DISMFile /Image:$ImageMountFolder /Add-Package /PackagePath:$AdobeFlashUpdate
Write-Progress -Activity 'Updating default image' -Status 'Add the Updates to the Windows image' -CurrentOperation 'Cumulative Update'
& $DISMFile /Image:$ImageMountFolder /Add-Package /PackagePath:$MonthlyCU

# Cleanup the image BEFORE installing .NET to prevent errors
# Using the /ResetBase switch with the /StartComponentCleanup parameter of DISM.exe on a running version of Windows 10 removes all superseded versions of every component in the component store.
# https://docs.microsoft.com/en-us/windows-hardware/manufacture/desktop/clean-up-the-winsxs-folder#span-iddismexespanspan-iddismexespandismexe
Write-Progress -Activity 'Updating default image' -Status 'Cleanup the image before installing .NET to prevent errors'
& $DISMFile /Image:$ImageMountFolder /Cleanup-Image /StartComponentCleanup /ResetBase

# Add .NET Framework 3.5.1 to the Windows 10 Enterprise image
Write-Progress -Activity 'Updating default image' -Status 'Add .NET Framework 3.5.1 to the Windows image '
& $DISMFile /Image:$ImageMountFolder /Enable-Feature /FeatureName:NetFx3 /All /LimitAccess /Source:"$ISODrive\sources\sxs"

# Re-apply CU because of .NET changes
Write-Progress -Activity 'Updating default image' -Status 'Add the Updates to the Windows 10 Enterprise image' -CurrentOperation 'Cumulative Update re-apply because of .NET changes'
& $DISMFile /Image:$ImageMountFolder /Add-Package /PackagePath:$MonthlyCU

# Move WinRE Image to temp location
Write-Progress -Activity 'Updating WinRE image' -Status 'Move image to temp location'
Move-Item -Path $ImageMountFolder\Windows\System32\Recovery\winre.wim -Destination $TmpWinREImage

# Mount the temp WinRE Image
Write-Progress -Activity 'Updating WinRE image' -Status 'Mount the temp image'
Mount-WindowsImage -ImagePath $TmpWinREImage -Index 1 -Path $BootImageMountFolder

# Add the Updates to the WinRE image
Write-Progress -Activity 'Updating WinRE image' -Status 'Add the Updates to the image' -CurrentOperation 'Servicing Update'
& $DISMFile /Image:$BootImageMountFolder /Add-Package /PackagePath:$ServicingUpdate
Write-Progress -Activity 'Updating WinRE image' -Status 'Add the Updates to the image' -CurrentOperation 'Cumulative Update'
& $DISMFile /Image:$BootImageMountFolder /Add-Package /PackagePath:$MonthlyCU

# Cleanup the WinRE image
Write-Progress -Activity 'Updating WinRE image' -Status 'Cleaning up the image'
& $DISMFile /Image:$BootImageMountFolder /Cleanup-Image /StartComponentCleanup /ResetBase

# Dismount the WinRE image
Write-Progress -Activity 'Updating WinRE image' -Status 'Save and dismount the image'
DisMount-WindowsImage -Path $BootImageMountFolder -Save

# Export new WinRE wim back to original location
Write-Progress -Activity 'Updating WinRE image' -Status 'Export new WinRE image back to original location'
Export-WindowsImage -SourceImagePath $TmpWinREImage -SourceName "Microsoft Windows Recovery Environment (x64)" -DestinationImagePath $ImageMountFolder\Windows\System32\Recovery\winre.wim

# Dismount the Windows 10 Enterprise image
Write-Progress -Activity 'Updating default image' -Status 'Save and dismount the image'
DisMount-WindowsImage -Path $ImageMountFolder -Save

# Export the Windows 10 Enterprise index to a new WIM (the export operation reduces the WIM size with about 400 - 500 MB)
Write-Progress -Activity 'Updating default image' -Status 'Export the Windows 10 Enterprise index to a new WIM' -CurrentOperation 'The export operation reduces the WIM size with about 400 - 500 MB'
Export-WindowsImage -SourceImagePath $TmpImage -SourceName "Windows 10 Enterprise" -DestinationImagePath $RefImage

# Remove the temporary WIM
Write-Progress -Activity 'Updating default image' -Status 'Remove the temporary WIM'
if (Test-Path -path $TmpImage) {Remove-Item -Path $TmpImage -Force}
if (Test-Path -path $TmpWinREImage) {Remove-Item -Path $TmpWinREImage -Force}

# Dismount the Windows 10 ISO
Write-Progress -Activity 'Cleanup' -Status 'Dismount the Windows ISO'
If (Test-Path -Path $ISODrive) {
	try {
		Dismount-DiskImage -ImagePath $ISO
	} catch {
		Write-Warning 'If an erorr occurred, run the following commands to dism and discard the mounted Images/WIMs and DiskImages/ISO:'
		Write-Warning "DisMount-WindowsImage -Path $BootImageMountFolder -Discard"
		Write-Warning "DisMount-WindowsImage -Path $ImageMountFolder -Discard"
		Write-Warning "DisMount-WindowsImage -Path $BootImageMountFolder -Discard"
		Write-Warning "Dismount-DiskImage -ImagePath $ISO"
	}
}

#TODO: Write-Output "Windows image servicing took $(Get-Date - $StartTime)"
Write-Output "Completed in $([math]::Round($(New-TimeSpan -Start $ScriptStartTime -End $(Get-Date)).TotalSeconds)) seconds, started at $(Get-Date -Date $ScriptStartTime -Format 'yyyy/MM/dd HH:mm:ss'), and ended at $(Get-Date -Format 'yyyy/MM/dd HH:mm:ss')"
Write-Output "The updated Windows image is located at $RefImage"
Write-Output "The updated boot image is located at $BootImage"