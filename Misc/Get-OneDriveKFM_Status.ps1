#https://github.com/OneDrive/onedrive-admin-scripts/blob/master/Scripts/Sync-KFM-Deployment/KFM_Deployment.ps1
<#
    .DESCRIPTION
        Script to gather KFM state that can help KFM planning and deployment.

        The sample scripts are not supported under any Microsoft standard support
        program or service. The sample scripts are provided AS IS without warranty
        of any kind. Microsoft further disclaims all implied warranties including,
        without limitation, any implied warranties of merchantability or of fitness for
        a particular purpose. The entire risk arising out of the use or performance of
        the sample scripts and documentation remains with you. In no event shall
        Microsoft, its authors, or anyone else involved in the creation, production, or
        delivery of the scripts be liable for any damages whatsoever (including,
        without limitation, damages for loss of business profits, business interruption,
        loss of business information, or other pecuniary loss) arising out of the use
        of or inability to use the sample scripts or documentation, even if Microsoft
        has been advised of the possibility of such damages.

        Author: Carter Green - cagreen@microsoft.com

        Deployment Guidance: https://docs.microsoft.com/en-us/onedrive/redirect-known-folders
#>
param (
	[Parameter(Mandatory = $false,  HelpMessage = 'OneDrive (Azure) Tenant ID')][Alias('TenantID')][string]$GivenTenantID = 'd0659de2-684e-49bd-9b1f-1fd4cd0942d9', #'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx',
	[Parameter(Mandatory = $false, HelpMessage = 'Log file path and name')][Alias('LogFile')][string]$OutputPath = $env:userProfile + '\OneDriveKFM_' + $env:USERNAME + "_" + $env:COMPUTERNAME + '.txt'
)
#CODE STARTS HERE

$PolicyState3 = ''
$PolicyState4 = ''
$KFMBlockOptInSet = 'False'
$KFMBlockOptOutSet = 'False'
$SpecificODPath = ''
$TotalItemsNotInOneDrive = 0
$TotalSizeNotInOneDrive = 0
[Long]$DesktopSize = 0
[Long]$DocumentsSize = 0
[Long]$PicturesSize = 0
$DesktopItems = 0
$DocumentsItems = 0
$PicturesItems = 0

$DesktopPath = [environment]::GetFolderPath("Desktop")
$DocumentsPath = [environment]::GetFolderPath("MyDocuments")
$PicturesPath = [environment]::GetFolderPath("MyPictures")

$ODAccounts = Get-ChildItem -Path HKCU:\Software\Microsoft\OneDrive\Accounts -name

$ODPath = foreach ($account in $ODAccounts){
    If($account -notlike 'Personal'){
        'HKCU:\Software\Microsoft\OneDrive\Accounts\' + $account
    }
}

foreach ($path in $ODPath){
    $ConfiguredTenantID = Get-ItemPropertyValue -path $path -name ConfiguredTenantID
    If ($GivenTenantID -eq $ConfiguredTenantID){
        $SpecificODPath = (Get-ItemPropertyValue -path $path -name UserFolder) + "\*"
        $KFMScanState = Get-ItemPropertyValue -path $path -name LastMigrationScanResult
        break
    }
}

$KFMGPOEligible = (($KFMScanState -ne 40) -and ($KFMScanState -ne 50))

$DesktopInOD = ($DesktopPath -like $SpecificODPath)
$DocumentsInOD = ($DocumentsPath -like $SpecificODPath)
$PicturesInOD = ($PicturesPath -like $SpecificODPath)

if(!$DesktopInOD){
    foreach ($item in (Get-ChildItem $DesktopPath -recurse | Where-Object {-not $_.PSIsContainer} | ForEach-Object {$_.FullName})) {
       $DesktopSize += (Get-Item $item).length
       $DesktopItems++
    }
}

if(!$DocumentsInOD){
    foreach ($item in (Get-ChildItem $DocumentsPath -recurse | Where-Object {-not $_.PSIsContainer} | ForEach-Object {$_.FullName})) {
       $DocumentsSize += (Get-Item $item).length
       $DocumentsItems++
    }
}

if(!$PicturesInOD){
	$PicturesFolder = Get-ChildItem -Path $PicturesPath -File -Recurse | Measure-Object -Sum Length | Select Folders, @{N='Files'; E={$_.Count}}, @{N='MB'; E={[math]::Round($($_.Sum)/1MB,0)}}
	$PicturesFolder.Folders = $(Get-ChildItem -Path $PicturesPath -Directory -Recurse).Count
	$PicturesFolder
    foreach ($item in (Get-ChildItem $PicturesPath -recurse | Where-Object {-not $_.PSIsContainer} | ForEach-Object {$_.FullName})) {
       $PicturesSize += (Get-Item $item).length
       $PicturesItems++
    }
}

$TotalItemsNotInOneDrive = $DesktopItems + $DocumentsItems + $PicturesItems
$TotalSizeNotInOneDrive = $DesktopSize + $DocumentsSize + $PicturesSize

Try{
	$PolicyState1 = Get-ItemPropertyValue -path HKLM:\SOFTWARE\Policies\Microsoft\OneDrive -name KFMOptInWithWizard -ErrorAction Stop
	$KFMOptInWithWizardSet = ($PolicyState1 -ne $null) -and ($PolicyState1 -eq $GivenTenantID)
}Catch{}

Try{
	$PolicyState2 = Get-ItemPropertyValue -path HKLM:\SOFTWARE\Policies\Microsoft\OneDrive -name KFMSilentOptIn -ErrorAction Stop
	$KFMSilentOptInSet = $PolicyState2 -eq $GivenTenantID
}Catch{}

Try{
	$PolicyState3 = Get-ItemPropertyValue -path HKLM:\SOFTWARE\Policies\Microsoft\OneDrive -name KFMBlockOptIn -ErrorAction Stop
	$KFMBlockOptInSet = ($PolicyState3 -ne $null) -and ($PolicyState3 -eq 1)
}Catch{}

Try{
	$PolicyState4 = Get-ItemPropertyValue -path HKLM:\SOFTWARE\Policies\Microsoft\OneDrive -name KFMBLockOptOut -ErrorAction Stop
	$KFMBlockOptOutSet = ($PolicyState4 -ne $null) -and ($PolicyState4 -eq 1)
}Catch{}

Try{
	$PolicyState5 = Get-ItemPropertyValue -path HKLM:\SOFTWARE\Policies\Microsoft\OneDrive -name KFMSilentOptInWithNotification -ErrorAction Stop
	$SendNotificationWithSilent = $PolicyState5 -eq 1
}Catch{}

Try{
	$ODVersion = Get-ItemPropertyValue -Path HKCU:\Software\Microsoft\OneDrive -Name Version -ErrorAction Stop
}Catch{}



Set-Content $OutputPath "$KFMGPOEligible | Device_is_KFM_GPO_eligible"
if(!$DesktopInOD -or !$DocumentsInOD -or !$PicturesInOD){
    Add-Content $OutputPath "$TotalItemsNotInOneDrive | Total_items_not_in_OneDrive"
    Add-Content $OutputPath "$TotalSizeNotInOneDrive | Total_size_bytes_not_in_OneDrive`n"
}
Add-Content $OutputPath "$DesktopInOD | Desktop_is_in_OneDrive"
if(!$DesktopInOD){
    Add-Content $OutputPath "$DesktopItems | Desktop_items"
    Add-Content $OutputPath "$DesktopSize | Desktop_size_bytes`n"
}
Add-Content $OutputPath "$DocumentsInOD | Documents_is_in_OneDrive"
if(!$DocumentsInOD){
    Add-Content $OutputPath "$DocumentsItems | Documents_items"
    Add-Content $OutputPath "$DocumentsSize | Documents_size_bytes`n"
}
Add-Content $OutputPath "$PicturesInOD | Pictures_is_in_OneDrive `n"
if(!$PicturesInOD){
    Add-Content $OutputPath "$PicturesItems | Pictures_items"
    Add-Content $OutputPath "$PicturesSize | Pictures_size_bytes`n"
}
Add-Content $OutputPath "$KFMOptInWithWizardSet | KFM_Opt_In_Wizard_Set"
Add-Content $OutputPath "$KFMSilentOptInSet | KFM_Silent_Opt_In_Set"
Add-Content $OutputPath "$SendNotificationWithSilent | KFM_Silent_With_Notification_Set"
Add-Content $OutputPath "$KFMBlockOptInSet | KFM_Block_Opt_In_Set"
Add-Content $OutputPath "$KFMBlockOptOutSet | KFM_Block_Opt_Out_Set `n"
Add-Content $OutputPath "$ODVersion | OneDrive Sync client version"