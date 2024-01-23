################################################################################
#.SYNOPSIS
#   Get-SCCMStatusMessageStrings.ps1
#	Export all Microsoft System Center Configuration Manager Status Message ID, Severity, Sources, and Description from Status Message resource DLLs
#.PARAMETER DLLPath
#   Folder path to ConfigMgr status message DLL files.  This should be "[ConfigMgr Primary Site install folder]\bin\X64\system32\smsmgs"
#   This is automatically detected and only needed as an override
#.PARAMETER OutputFile
#   Full Folder Path and File Name to export the results to.  The results are exported to a Tab Separated Values file (TSV) similar to a Comma Separated Values file (CSV)
#   The Current path/location is used if not specified
#.EXAMPLE
#   Get-SCCMStatusMessageStrings.ps1
#   Execute the script with default values
#.EXAMPLE
#   Get-SCCMStatusMessageStrings.ps1 -DLLPath \\localhost\sms_XYZ\bin\X64\system32\smsmgs -OutputFile \\localhost\Share$\Folder\File.tsv
#   Execute the script specifying all parameters
#.LINK
#	Based on https://blogs.technet.microsoft.com/saudm/2015/01/19/enumerating-status-message-strings-in-powershell/
#			 https://gallery.technet.microsoft.com/Enumerate-status-message-6e7e1761
#	Also see https://gregramsey.net/2014/12/29/how-to-extract-status-message-information-from-configmgr-2012-r2/
#	Also see https://technet.microsoft.com/en-ca/library/bb632794.aspx?#BKMK_Software_Distribution
#.NOTES
#   This script is maintained at https://github.com/ChadSimmons/Scripts
#   Additional information about the function or script.
#   ========== Keywords ==========
#   Keywords: ConfigMgr SCCM Status Messages
#   ========== Change Log History ==========
#   - 2018/01/03 by Chad.Simmons@CatapultSystems.com - Created
#   - 2018/01/03 by Chad@ChadsTech.net - Created
#   === To Do / Proposed Changes ===
#   - TODO: None
################################################################################
#region    ######################### Parameters and variable initialization ####
param(
    [Parameter(HelpMessage='Folder path to ConfigMgr status message DLL files.  This should be "[ConfigMgr Primary Site install folder]\bin\X64\system32\smsmgs"')][ValidateScript({[IO.Directory]::Exists($_)})]
	[System.IO.DirectoryInfo]$DLLPath = $(((Get-ItemProperty -Path registry::HKLM\SOFTWARE\Microsoft\SMS\Setup | Select-Object 'Installation Directory').'Installation Directory') + '\bin\X64\system32\smsmsgs'),
    [Parameter()][ValidateScript({If ((Split-Path $_ -Leaf).IndexOfAny([IO.Path]::GetInvalidFileNameChars()) -ge 0) { Throw "$(Split-Path $_ -Leaf) contains invalid characters!" } Else { $True } })]
    [string]$OutputFile = 'Get-SCCMStatusMessageStrings.tsv'
)

If (-not(Test-Path -Path $DLLPath)) { Write-Error "The DLLpath [$DLLpath] does not exist or is not accessible"; Exit 2 }
$ScriptStart = Get-Date
$sizeOfBuffer = [int]16384
$stringArrayInput = {"%1","%2","%3","%4","%5","%6","%7","%8","%9"}
$flags = 0x00000800 -bor 0x00000200
$stringOutput = New-Object System.Text.StringBuilder $sizeOfBuffer
$colMessages = @()
$SeverityHT = @{'Informational' = 1073741824; 'Warning'= 2147483648; 'Error'= 3221225472}
$DLLfilesHT = @{'Client' = 'climsgs.dll'; 'SMSProvider'= 'provmsgs.dll'; 'Server'= 'srvmsgs.dll'}
$ProgressHT = @{'Activity' = 'Starting Activity'; 'Status'= 'Starting Status'; 'PercentComplete' = 0; }
#endregion ######################### Parameters and variable initialization ####

#region    ######################### PInvoke Code
$sigFormatMessage = @'
[DllImport("kernel32.dll")]
public static extern uint FormatMessage(uint flags, IntPtr source, uint messageId, uint langId, StringBuilder buffer, uint size, string[] arguments);
'@

$sigGetModuleHandle = @'
[DllImport("kernel32.dll")]
public static extern IntPtr GetModuleHandle(string lpModuleName);
'@

$sigLoadLibrary = @'
[DllImport("kernel32.dll")]
public static extern IntPtr LoadLibrary(string lpFileName);
'@

$Win32FormatMessage = Add-Type -MemberDefinition $sigFormatMessage -name "Win32FormatMessage" -namespace Win32Functions -PassThru -Using System.Text
$Win32GetModuleHandle = Add-Type -MemberDefinition $sigGetModuleHandle -name "Win32GetModuleHandle" -namespace Win32Functions -PassThru -Using System.Text
$Win32LoadLibrary = Add-Type -MemberDefinition $sigLoadLibrary -name "Win32LoadLibrary" -namespace Win32Functions -PassThru -Using System.Text
#endregion ######################### PInvoke Code

$Phase = 0
ForEach ($DLLfile in $DLLfilesHT.GetEnumerator()) {
    $Phase++
    $ProgressHT.PercentComplete = (($Phase/[math]::pow($DLLfilesHT.Count, $SeverityHT.Count)) * 100)
    $ProgressHT.Activity = "Processing $($DLLfile.Name) status message DLL $($DLLfile.Value)"
    $ProgressHT.Status = "Load Status Message Lookup DLL into memory and get pointer to memory"
    Write-Progress @ProgressHT
    try {
        $ptrFoo = $Win32LoadLibrary::LoadLibrary($DLLPath.FullName + '\' + $($DLLfile.Value))
        $ptrModule = $Win32GetModuleHandle::GetModuleHandle($DLLPath.FullName + '\' + $($DLLfile.Value))
    } catch { Write-Error $_; break }

    ForEach ($Severity in $SeverityHT.GetEnumerator()) {
        $Phase++
        $ProgressHT.PercentComplete = (($Phase/[math]::pow($DLLfilesHT.Count, $SeverityHT.Count)) * 100)
        $ProgressHT.Status = "Getting Messages for severity $($Severity.Name) which have an ID of $($Severity.Value)"
        Write-Progress @ProgressHT
        $colMessages += for ($iMessageID = 1; $iMessageID -ile 99999; $iMessageID++) {
            #If ($iMessageID % 1000 -eq 0) {
            #    #Show more status updates, but don't slow down the processing with a progress bar... only refresh every x Message IDs
            #    Write-Progress @ProgressHT -CurrentOperation "Processing MessageID $iMessageID"
            #}
            $result = $Win32FormatMessage::FormatMessage($flags, $ptrModule, $($Severity.Value) -bor $iMessageID, 0, $stringOutput, $sizeOfBuffer, $stringArrayInput)
            if( $result -gt 0) {
                $objMessage = New-Object System.Object
                $objMessage | Add-Member -type NoteProperty -name MessageID -value $iMessageID
                $objMessage | Add-Member -type NoteProperty -name Severity -value "$($Severity.Name)"
                $objMessage | Add-Member -type NoteProperty -name Source -value "$($DLLfile.Name)"
                $objMessage | Add-Member -type NoteProperty -name MessageString -value $stringOutput.ToString().Replace("%11","").Replace("%12","").Replace("%3%4%5%6%7%8%9%10","")
                $objMessage
            }
        }
    }
}
Write-Progress @ProgressHT -CurrentOperation "Exporting results to $OutputFile"
$colMessages | Sort-Object Source, MessageID | Export-CSV -path $OutputFile -NoTypeInformation -Delimiter "`t"

$ScriptEnd = Get-Date
$ScriptTimeSpan = New-TimeSpan -Start $ScriptStart -End $ScriptEnd
Write-Output "Script Completed in $([math]::Round($ScriptTimeSpan.TotalSeconds)) seconds, started at $(Get-Date $ScriptStart -Format 'yyyy/MM/dd hh:mm:ss'), and ended at $(Get-Date $ScriptEnd -Format 'yyyy/MM/dd hh:mm:ss')"
Write-Output "Exported results to $OutputFile"
Write-Output "==================== SCRIPT COMPLETE ===================="