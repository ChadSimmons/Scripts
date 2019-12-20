################################################################################
#.SYNOPSIS
#   Set-QualityCompatReg.ps1
#   Create / Set the registry key to all Windows 7/2008 R2 and newer operating systems to continue receiving Microsoft
#   Updates (patches) after January 2018.  This setting is related to the Meltdown and Spectre vulnerabilities.
#.LINK
#   Important: Windows security updates released January-February, 2018, and antivirus software (KB4072699)
#   https://support.microsoft.com/en-us/help/4072699/january-3-2018-windows-security-updates-and-antivirus-software
#.NOTES
#   This script is maintained at https: //github.com/ChadSimmons/Scripts
#   Additional information about the function or script.
#   ========== Change Log History ==========
#   - 2018/02/16 by Chad.Simmons@CatapultSystems.com - Created
#   - 2018/02/16 by Chad@ChadsTech.net - Created
################################################################################

#region    ######################### Main Script ###############################
$RegPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\QualityCompat'
$RegName = 'cadca5fe-87d3-4b96-b7fb-a231484277cc'
New-Item -Path "$RegPath" -ItemType 'Key' -ErrorAction SilentlyContinue
New-ItemProperty -Path "$RegPath" -Name "$RegName" -Value 0 -PropertyType 'DWORD' -Force -ErrorAction SilentlyContinue
If ($(Get-ItemProperty -Path "$RegPath" -Name $RegName).$RegName -ne 0) { Exit 2 }
#endregion ######################### Main Script ###############################