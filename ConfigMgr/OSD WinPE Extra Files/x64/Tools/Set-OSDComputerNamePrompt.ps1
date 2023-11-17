#.SYNOPSIS
#   Set-OSDComputerNamePrompt.ps1
#   Prompt and set the ConfigMgr (SCCM) Operating System Deployment (OSD) Task Sequence variable OSDComputerName
#.EXAMPLE
#   ServiceUI.exe -process:TSProgressUI.exe %SYSTEMROOT%\System32\WindowsPowerShell\v1.0\powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File Set-OSDComputerNamePrompt.ps1
#.LINK https://gist.github.com/davegreen/453cee5ef2db1063a007
#.LINK https://msendpointmgr.com/2013/10/02/prompt-for-computer-name-during-osd-with-powershell/

Function Load-Form {
    $Form.Controls.Add($TBComputerName)
    $Form.Controls.Add($GBComputerName)
    $Form.Controls.Add($ButtonOK)
    $Form.Add_Shown({$Form.Activate()})
    [void] $Form.ShowDialog()
}
 
Function Set-OSDComputerName {
    $ErrorProvider.Clear()
    if ($TBComputerName.Text.Length -eq 0) {
        $ErrorProvider.SetError($GBComputerName, "Please enter a computer name.")
    } elseif ($TBComputerName.Text.Length -gt 15) {
        $ErrorProvider.SetError($GBComputerName, "Computer name cannot be more than 15 characters.")
	} elseif ($TBComputerName.Text -match "^[-_]|[^a-zA-Z0-9-_]") { #Validation Rule for computer names
        $ErrorProvider.SetError($GBComputerName, "Computer name invalid, please correct the computer name.")
    } else {
        $OSDComputerName = $TBComputerName.Text.ToUpper()
        $TSEnv = New-Object -COMObject Microsoft.SMS.TSEnvironment
        $TSEnv.Value("OSDComputerName") = "$($OSDComputerName)"
        $Form.Close()
    }
}
 
[void][System.Reflection.Assembly]::LoadWithPartialName("System.Drawing")
[void][System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
 
$Global:ErrorProvider = New-Object System.Windows.Forms.ErrorProvider
 
$Form = New-Object System.Windows.Forms.Form    
$Form.Size = New-Object System.Drawing.Size(285,140)  
$Form.MinimumSize = New-Object System.Drawing.Size(285,140)
$Form.MaximumSize = New-Object System.Drawing.Size(285,140)
$Form.StartPosition = "CenterScreen"
$Form.SizeGripStyle = "Hide"
$Form.Text = "Enter Computer Name"
$Form.ControlBox = $false
$Form.TopMost = $true
 
$TBComputerName = New-Object System.Windows.Forms.TextBox
$TBComputerName.Location = New-Object System.Drawing.Size(25,30)
$TBComputerName.Size = New-Object System.Drawing.Size(215,50)
$TBComputerName.TabIndex = "1"
 
$GBComputerName = New-Object System.Windows.Forms.GroupBox
$GBComputerName.Location = New-Object System.Drawing.Size(20,10)
$GBComputerName.Size = New-Object System.Drawing.Size(225,50)
$GBComputerName.Text = "Computer name:"
 
$ButtonOK = New-Object System.Windows.Forms.Button
$ButtonOK.Location = New-Object System.Drawing.Size(195,70)
$ButtonOK.Size = New-Object System.Drawing.Size(50,20)
$ButtonOK.Text = "OK"
$ButtonOK.TabIndex = "2"
$ButtonOK.Add_Click({Set-OSDComputerName})

$Form.KeyPreview = $True
$Form.Add_KeyDown({if ($_.KeyCode -eq "Enter"){Set-OSDComputerName}})

Load-Form