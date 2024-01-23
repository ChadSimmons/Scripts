#Get-MSIFileInformationEx.ps1
#by Chad.Simmons@CatapultSystems.com
#based on https://github.com/NickolajA/PowerShell/blob/master/ConfigMgr/Application/Get-MSIFileInformation.ps1

#TODO: proper header and inline comments
#TODO: extract icons like CSI_ExtractMSIGUIDAndIcons.vbs
param(
    [parameter(Mandatory=$true)][ValidateScript({Test-Path -LiteralPath $_ -PathType Leaf})][string]$Path, #e:\xfer\anyconnect-win-4.9.05042-core-vpn-predeploy-k9.msi
    [parameter(Mandatory=$false)][ValidateSet('ProductCode','ProductVersion','ProductName','*')][string]$Property
)

#get the $Path item because the COM object requires a full path
$MSIFile = Get-Item -Path $Path

#Set list of MSI Property Names to get if none specified
If ($Property -eq '*' -or $Property -eq '' -or $null -eq $Property) {
    $MSIPropertyNames = @('Manufacturer', 'ProductName', 'ProductVersion', 'ProductVersionMarketing', 'ProductLanguage', 'ProductCode', 'UpgradeCode', 'Author', 'Comments')
} Else {
    $MSIPropertyNames = @($Property)
}
try {
    $WindowsInstaller = New-Object -ComObject WindowsInstaller.Installer
    $MSIDatabase = $WindowsInstaller.GetType().InvokeMember("OpenDatabase", "InvokeMethod", $Null, $WindowsInstaller, @($MSIFile.FullName, 0))
} catch {
    Write-Output $_.Exception.Message; break
}
$MSIProperties = [ordered]@{}
ForEach ($PropertyName in $MSIPropertyNames) {
    try {
        $View = $MSIDatabase.GetType().InvokeMember("OpenView", "InvokeMethod", $null, $MSIDatabase, "SELECT Value FROM Property WHERE Property = '$($PropertyName)'")
        $View.GetType().InvokeMember("Execute", "InvokeMethod", $null, $View, $null)
        $Record = $View.GetType().InvokeMember("Fetch","InvokeMethod",$null,$View,$null)
        $Value = $Record.GetType().InvokeMember("StringData", "GetProperty", $null, $Record, 1)
    } catch {}
    $MSIProperties.Add($PropertyName, $Value)
    Remove-Variable -Name View, Record, Value -ErrorAction SilentlyContinue
}
$MSIProperties.Add('FileFullPath', $MSIFile)
$MSIProperties.Add('FilePath', $MSIFile.Directory)
$MSIProperties.Add('FileName', $MSIFile.Name)
$MSIProperties.Add('FileSizeInBytes', $MSIFile.Length)
$MSIProperties.Add('FileSizeInMB', [math]::Round($($MSIFile.Length) / 1MB, 2))
$MSIProperties

<#
#TODO: table with optional variables: Directory -> Directory = INSTALLDIR, Directory, 'Directory Parent', 'DefaultDir'
$View = $MSIDatabase.GetType().InvokeMember("OpenView", "InvokeMethod", $null, $MSIDatabase, "SELECT Directory FROM Directory WHERE Directory = 'INSTALLDIR'")
$View.GetType().InvokeMember("Execute", "InvokeMethod", $null, $View, $null)
$Record = $View.GetType().InvokeMember("Fetch", "InvokeMethod", $null, $View, $null)
$Value = $Record.GetType().InvokeMember("StringData", "GetProperty", $null, $Record, 1)
$Value
$MSIProperties.Add($PropertyName, $Value)

#TODO: table with 1+ rows: Upgrade -> UpgradeCode, VersionMin, VersionMax, Language, Attributes, Remove, ActionProperty
$View = $MSIDatabase.GetType().InvokeMember("OpenView", "InvokeMethod", $null, $MSIDatabase, "SELECT VersionMin FROM Upgrade")
$View.GetType().InvokeMember("Execute", "InvokeMethod", $null, $View, $null)
$Record = $View.GetType().InvokeMember("Fetch", "InvokeMethod", $null, $View, $null)
$Value = $Record.GetType().InvokeMember("StringData", "GetProperty", $null, $Record, 1)
$Value
#>