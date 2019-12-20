#.Synopsis
#	Encode and Decode text in Base64
	
$strPassword = 'Same_as_Install_Account'
If([string]::IsNullOrEmpty($strPassword)) { $strPassword = Read-Host 'Enter Password' }

#$strPasswordIn64 = [System.Convert]::ToBase64String([System.Text.Encoding]::GetBytes($strPassword))
#$strPasswordFrom64 = [System.Text.Encoding]::GetString([System.Convert]::FromBase64String($strPasswordIn64))

$strPasswordIn64_Unicode = [System.Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($strPassword))
$strPasswordFrom64_Unicode = [System.Text.Encoding]::Unicode.GetString([System.Convert]::FromBase64String($strPasswordIn64_Unicode))

$strPasswordIn64_UTF8 = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($strPassword))
$strPasswordFrom64_UTF8 = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($strPasswordIn64_UTF8))

$strPasswordIn64_UTF7 = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF7.GetBytes($strPassword))
$strPasswordFrom64_UTF7 = [System.Text.Encoding]::UTF7.GetString([System.Convert]::FromBase64String($strPasswordIn64_UTF7))

$strPasswordIn64_UTF32 = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF32.GetBytes($strPassword))
$strPasswordFrom64_UTF32 = [System.Text.Encoding]::UTF32.GetString([System.Convert]::FromBase64String($strPasswordIn64_UTF32))


Write-Host "Password Entered: $($strPassword)"
#Write-Host "Password converted to Base64: $strPasswordIn64"
#Write-Host "Password converted from Base64: $strPasswordFrom64"
Write-Host "Password converted to Base64 (Unicode): $strPasswordIn64_Unicode"
Write-Host "Password converted from Base64 (Unicode): $strPasswordFrom64_Unicode"
Write-Host "Password converted to Base64 (UTF-8): $strPasswordIn64_UTF8"
Write-Host "Password converted from Base64 (UTF-8): $strPasswordFrom64_UTF8"
Write-Host "Password converted to Base64 (UTF-7): $strPasswordIn64_UTF7"
Write-Host "Password converted from Base64 (UTF-7): $strPasswordFrom64_UTF7"
Write-Host "Password converted to Base64 (UTF-32): $strPasswordIn64_UTF32"
Write-Host "Password converted from Base64 (UTF-32): $strPasswordFrom64_UTF32"
If ($strPassword -ne $strPasswordFrom64_Unicode) { throw "The decoded password does not match the original" }
