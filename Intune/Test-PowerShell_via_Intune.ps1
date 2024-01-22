$OutputFile = "$env:ProgramData\Microsoft\Intune Management Extension\Logs\Intune PowerShell script test.log"
Add-Content -Path $OutputFile -Value "Intune invoked a PowerShell script at $(Get-Date)"
If (Test-Path -Path $OutputFile -PathType Leaf) {
	exit 0
} Else {
	Write-Error -Message 'File not found'
	Exit 2
}