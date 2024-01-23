<#
.Example
	.\Get-MSIFileInformation.ps1 -Path "D:\Source$\Apps\7-zip\7z920-x64.msi" -Property ProductCode
.Link
   https://msendpointmgr.com/2014/08/22/how-to-get-msi-file-information-with-powershell/
   https://github.com/NickolajA/PowerShell/blob/master/ConfigMgr/Application/Get-MSIFileInformation.ps1
#>

param(
[parameter(Mandatory=$true)]
[IO.FileInfo]$Path,
[parameter(Mandatory=$true)]
[ValidateSet("ProductCode","ProductVersion","ProductName")]
[string]$Property
)
try {
    $WindowsInstaller = New-Object -ComObject WindowsInstaller.Installer
    $MSIDatabase = $WindowsInstaller.GetType().InvokeMember("OpenDatabase","InvokeMethod",$Null,$WindowsInstaller,@($Path.FullName,0))
    $Query = "SELECT Value FROM Property WHERE Property = '$($Property)'"
    $View = $MSIDatabase.GetType().InvokeMember("OpenView","InvokeMethod",$null,$MSIDatabase,($Query))
    $View.GetType().InvokeMember("Execute", "InvokeMethod", $null, $View, $null)
    $Record = $View.GetType().InvokeMember("Fetch","InvokeMethod",$null,$View,$null)
    $Value = $Record.GetType().InvokeMember("StringData","GetProperty",$null,$Record,1)
    return $Value
} 
catch {
    Write-Output $_.Exception.Message
}