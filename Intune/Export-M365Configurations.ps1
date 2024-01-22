#Export-M365Configurations.ps1
$StartTime = Get-Date
$StartTimeFormatted = $StartTime.ToString('yyyyMMddHHmm')



#CECO Environmental
$ClientID = '11111111-2222-3333-4444-555555555555'
$TenantID = '11111111-2222-3333-4444-555555555555'
$SecretID = '11111111-2222-3333-4444-555555555555'
$SecretKey = 'uQT8Q~dRCoTA949UMcWA-U9UdRCoTAlG84d4V7ZfN-9d4F_bxX'


$BasePath = $(Join-Path -Path $([System.Environment]::GetFolderPath('Personal')) -ChildPath 'Scripted Documentation')
If (-not(Test-Path -Path $BasePath -PathType Container -ErrorAction SilentlyContinue)) {
	New-Item -ItemType Directory -Path $BasePath -ErrorAction SilentlyContinue
}

#region ===== Automated Microsoft 365 Documentation by Thomas Kurth ====================================================
#https://github.com/ThomasKur/M365Documentation
Install-Module MSAL.PS
Install-Module PSWriteWord
Install-Module M365Documentation
#Import-Module M365Documentation


Function Write-M365DocumentationEx ($doc, $FullDocumentationPath) {
	# Output the documentation
	$doc | Write-M365DocJson -FullDocumentationPath "$FullDocumentationPath.json" -Verbose
	$doc | Write-M365DocWord -FullDocumentationPath "$FullDocumentationPath.docx" -Verbose

	$CSVPath = $(Join-Path -Path $env:SystemDrive -ChildPath $([System.IO.Path]::GetRandomFileName()))
	If (-not(Test-Path -Path $CSVPath -PathType Container -ErrorAction SilentlyContinue)) {
		[void](New-Item -ItemType Directory -Path $CSVPath -ErrorAction SilentlyContinue)
	}
	$doc | Write-M365DocCsv -ExportFolder $CSVPath -Verbose
	Compress-Archive -Path "$CSVPath\*.*" -DestinationPath "$FullDocumentationPath - CSV.zip"
	Remove-Item -Path $CSVPath -Recurse -Force
}

# Connect to your tenant
#Connect-M365Doc
Connect-M365Doc -ClientID $ClientID -TenantId $TenantID

# Collect information for component Intune
$doc = Get-M365Doc -Components Intune -ExcludeSections 'MobileAppDetailed'
#$StartTimeFormatted = $doc.CreationDate.ToString('yyyyMMddHHmm')

$OrgPath = Join-Path -Path $BasePath -ChildPath $($doc.Organization)
If (-not(Test-Path -Path $OrgPath -PathType Container -ErrorAction SilentlyContinue)) {
	New-Item -ItemType Directory -Path $OrgPath -ErrorAction SilentlyContinue
}

Write-M365DocumentationEx -Doc $doc -FullDocumentationPath "$OrgPath\M365 Automated Documentation - $($doc.Organization) - $($doc.Components) - $StartTimeFormatted"
Remove-Variable -Name doc

# Collect information for component AzureAD
$doc = Get-M365Doc -Components AzureAD -IncludeSections AADConditionalAccess, AADBranding, AADOrganization, AADPolicy, AADSubscription, AADDirectoryRole, AADDomain
Write-M365DocumentationEx -Doc $doc -FullDocumentationPath "$OrgPath\M365 Automated Documentation - $($doc.Organization) - $($doc.Components) - $StartTimeFormatted"
Remove-Variable -Name doc, BasePath, OrgPath

#endregion ===== Automated Microsoft 365 Documentation by Thomas Kurth ================================================>