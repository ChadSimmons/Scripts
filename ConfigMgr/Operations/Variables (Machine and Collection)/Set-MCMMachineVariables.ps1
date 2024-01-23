#Based on http://www.david-obrien.net/2012/05/create-machine-variables-in-configuration-manager-2012/

Function Get-CMResourceID ($SMSProvider, $SiteCode, $ComputerName) {
    #.Synopsis
    #   Get the System/Computer ResourceID (unique identifier) from ConfigMgr based on the system name
    #.Example
    #   Get-CMResourceID -SMSProvider "PrimarySiteServer.contoso.com" -SiteCode "CM1" -ComputerName "Laptop1234"
    Write-Verbose "Get-CMResourceID ($SMSProvider, $SiteCode, $ComputerName)"
    try {
        $ErrorActionPreference = 'Stop' #for all errors to be terminating http://stackoverflow.com/questions/1142211/try-catch-does-not-seem-to-have-an-effect
        $Computer = Get-WMIobject -ComputerName $SMSProvider -namespace "root\sms\site_$SiteCode" -class "sms_r_system" | where {$_.Name -eq $ComputerName} -ErrorAction Stop
        If($Computer) {
            Write-Verbose "   Computer:$Computer"
            Return [int]$Computer.ResourceID
        } else { 
            Return 0
        }
    } catch {
        throw $error[0].Exception
    }
    $ErrorActionPreference = 'Continue'
}

Function Get-CMMachineVariables ($SMSProvider, $SiteCode, $ComputerName) {
    #.Synopsis
    #   Get a hashtable of the Machine Variables assigned to a System/Computer
    #.Example
    #   Get-CMMachineVariables -SMSProvider "PrimarySiteServer.contoso.com" -SiteCode "CM1" -ComputerName "Laptop1234"
    Write-Verbose "Get-CMMachineVariables ($SMSProvider, $SiteCode, $ComputerName)"
    $ResourceID = Get-CMResourceID -SMSProvider $SMSProvider -SiteCode $SiteCode -ComputerName $ComputerName
    $MachineSettings = Get-WMIobject -ComputerName "$SMSProvider" -namespace "root\sms\site_$SiteCode" -class "sms_machinesettings" | Where {$_.ResourceID -eq $ResourceID}
    Write-Verbose "   MachineSettings: $MachineSettings"
    $MachineSettings.get()
    Write-Verbose "   MachineVariables: $($MachineSettings.MachineVariables)"
    Return @($MachineSettings.MachineVariables | Select Name, Value)
}

Function Set-CMMachineVariable ($SMSProvider, $SiteCode, $ComputerName, $VarName, $VarValue) {
    #.Synopsis
    #   Create/Update a Machine Variable for a System/Computer
    #.Example
    #   Set-CMMachineVariable -SMSProvider "PrimarySiteServer.contoso.com" -SiteCode "CM1" -ComputerName "Laptop1234" -VarName "DateImaged" -VarValue "2016/02/12"
    Write-Verbose "Set-CMMachineVariable ($SMSProvider, $SiteCode, $ComputerName, $VarName, $VarValue)"
    $ResourceID = Get-CMResourceID -SMSProvider $SMSProvider -SiteCode $SiteCode -ComputerName $ComputerName
    $MachineSettings = Get-WMIobject -ComputerName $SMSProvider -Namespace "Root\SMS\Site_$SiteCode" -Class "SMS_MachineSettings" | where {$_.ResourceID -eq $ResourceID}
    # Create new instance of MachineSettings if not found
    If (!$MachineSettings) {
        $RecourceID = Get-CMResourceID -SMSProvider $SMSProvider -SiteCode $SiteCode -ComputerName $ComputerName
        $NewMachineSettingsInstance = $([wmiclass]"\\$SMSProvider\Root\SMS\Site_$($SiteCode):SMS_MachineVariable").CreateInstance()
        $NewMachineSettingsInstance.ResourceID = $ResourceID
        $NewMachineSettingsInstance.SourceSite = $SiteCode
        $NewMachineSettingsInstance.LocaleID = 1033
        $NewMachineSettingsInstance.psbase
        $NewMachineSettingsInstance.psbase.Put()
        $MachineSettings += $NewMachineSettingsInstance
        Write-Verbose "   Creating MachineSettings Instance"
    }
    Write-Verbose "   MachineSettings: $MachineSettings"

    $MachineSettings.psbase.Get()
    $MachineVariables = $MachineSettings.MachineVariables
    Write-Verbose "   MachineVariables: $MachineVariables"
    $ConfigMgrVar = $([wmiclass]"\\$SMSProvider\Root\SMS\Site_$($SiteCode):SMS_MachineVariable").CreateInstance()
    $ConfigMgrVar.Name = "$VarName"
    $ConfigMgrVar.Value = "$VarValue"
    Write-Verbose "   ConfigMgrVar: ConfigMgrVar"
    [System.Management.ManagementBaseObject[]]$MachineVariables += $ConfigMgrVar
    $MachineSettings.MachineVariables = $MachineVariables
    try {
        $MachineSettings.psbase.Put() | Out-Null
        Return 0
    } catch {
        throw $_
    }
}

Function Remove-CMMachineVariable ($SMSProvider, $SiteCode, $ComputerName, $VarName) {
    #.Synopsis
    #   Delete a Machine Variable for a System/Computer
    #.Example
    #   Remove-CMMachineVariable -SMSProvider "PrimarySiteServer.contoso.com" -SiteCode "CM1" -ComputerName "Laptop1234" -VarName "DateImaged"
    Write-Verbose "Remove-CMMachineVariable ($SMSProvider, $SiteCode, $ComputerName, $VarName)"
    $ResourceID = Get-CMResourceID -SMSProvider $SMSProvider -SiteCode $SiteCode -ComputerName $ComputerName
    $MachineSettings = Get-WMIobject -ComputerName $SMSProvider -Namespace "Root\SMS\Site_$SiteCode" -Class "SMS_MachineSettings" | where {$_.ResourceID -eq $ResourceID}
    # Create new instance of MachineSettings if not found
    If ($MachineSettings) {
        Write-Verbose "   MachineSettings: $MachineSettings"
        $MachineSettings.psbase.Get()
        If (($MachineSettings.MachineVariables | Where {$_.Name -ne $VarName}).count -eq 0) {
            Write-Verbose "  Deleting the last/only variable.  Add a placeholder variable until code can be worked out to actaully delete the last variable"
            Set-CMMachineVariable  -SMSProvider $SMSProvider -SiteCode $SiteCode -ComputerName $ComputerName -VarName "Placeholder" -VarValue "none"
            $MachineSettings.psbase.Get()
        }
        [System.Management.ManagementBaseObject[]]$MachineSettings.MachineVariables = $MachineSettings.MachineVariables | Where {$_.Name -ne $VarName}
        try {
            $MachineSettings.psbase.Put() | Out-Null
            Return 0
        } catch {
            throw $_
        }
    } else {
        #Machine variables do not exist for the computer thus nothing to delete
    }
}

<# debug
$VarName = "CRQID"
$VarValue = "CHG003"
$ComputerName = "Lab-DC1"
$SiteCode = "LAB"
$SMSProvider = 'Lab-CM1.lab.local'
$ResourceID = Get-CMResourceID -SMSProvider $SMSProvider -SiteCode $SiteCode -ComputerName 'Lab-DC1'

$ErrorActionPreference
$VerbosePreference = 'SilentlyContinue' #'Continue'
Remove-Variable VarName, VarValue, ResourceID -ErrorAction SilentlyContinue
Get-CMResourceID -SMSProvider $SMSProvider -SiteCode $SiteCode -ComputerName $ComputerName
#>

#Backup the last CRQID and set a new one
$Vars = Get-CMMachineVariables -SMSProvider $SMSProvider -SiteCode $SiteCode -ComputerName $ComputerName
$Vars | Format-Table -AutoSize
ForEach ($Var in ($Vars | Where { $_.Name -eq "CRQID"})) {
    Set-CMMachineVariable  -SMSProvider $SMSProvider -SiteCode $SiteCode -ComputerName $ComputerName -VarName "CRQIDprevious" -VarValue "$($Var.Value)"
}
Set-CMMachineVariable  -SMSProvider $SMSProvider -SiteCode $SiteCode -ComputerName $ComputerName -VarName "CRQID" -VarValue "CHG0007"
Get-CMMachineVariables -SMSProvider $SMSProvider -SiteCode $SiteCode -ComputerName $ComputerName | Format-Table -AutoSize

#Remove CRQID variables
Remove-CMMachineVariable  -SMSProvider $SMSProvider -SiteCode $SiteCode -ComputerName $ComputerName -VarName "CRQIDprevious"
Remove-CMMachineVariable  -SMSProvider $SMSProvider -SiteCode $SiteCode -ComputerName $ComputerName -VarName "CRQID"
Get-CMMachineVariables -SMSProvider $SMSProvider -SiteCode $SiteCode -ComputerName $ComputerName | Format-Table -AutoSize
