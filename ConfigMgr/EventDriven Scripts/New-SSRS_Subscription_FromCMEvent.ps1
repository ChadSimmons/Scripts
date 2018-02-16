#.Synopsis
#   New-SSRS_Subscription_FromCMEvent.ps1
#.Example
#   From a ConfigMgr Status Message Filter Rule
#   "C:\Windows\System32\WindowsPowerShell\v1.0\PowerShell.exe" -ExecutionPolicy Bypass -NoProfile -File "E:\Scripts\New-SSRS_Subscription_FromCMEvent.ps1" -SSRSServer Bourne.FHLB.com -SiteServer %sitesvr -SiteCode %sc -DeploymentID "%msgis01 %msgis02 %msgis03 %msgis04 %msgis05 %msgis06" -MessageID %msgid
#.Example
#   PowerShell.exe -NoProfile -ExecutionPolicy Bypass -File New-SSRS_Subscription_FromCMEvent.ps1 -DeploymentID DAL20017 -MessageID 30006
#.Example
#   PowerShell.exe -NoProfile -ExecutionPolicy Bypass -File New-SSRS_Subscription_FromCMEvent.ps1 -DeploymentID DAL20017 -MessageID 30006
#.Link
#   Command-Line Parameters for Status Filter Rules https://technet.microsoft.com/en-us/library/bb693758.aspx
#   Sample Status Filter Rules https://technet.microsoft.com/en-us/library/cc181183.aspx
#.Note
#  Create as a ConfigMgr Status Filter Rule
#     New-CMStatusFilterRule -SiteCode PS1 -Name 'Create Deployment Email Status Subscription' -ComponentName 'Microsoft.ConfigurationManagement.exe' -MessageType Audit -SeverityType Informational -WriteToDatabase -AllowDeleteAfterDays 999 -ReportToEventLog`
#        -RunProgram $True -ProgramPath '"C:\Windows\System32\WindowsPowerShell\v1.0\PowerShell.exe" -ExecutionPolicy Bypass -NoProfile -File "E:\Scripts\New-SSRS_Subscription_FromCMEvent.ps1" -SSRSServer CMssrs.contoso.com -SiteServer %sitesvr -SiteCode %sc -DeploymentID %msgis02 -MessageID %msgid'


[cmdletbinding()]
Param (
    [parameter(Mandatory=$false,Position=0,ValueFromPipeline)][ValidateNotNullOrEmpty()][string]$SSRSServer = 'localhost',
    [parameter(Mandatory=$false,Position=1,ValueFromPipeline)][ValidateNotNullOrEmpty()][string]$SiteServer = 'localhost',
    [parameter(Mandatory=$false,Position=2,ValueFromPipeline)][string]$SiteCode,
    [parameter(Mandatory=$false,Position=3,ValueFromPipeline)][string]$ReportPathRoot = 'ConfigMgr',
    [parameter(Mandatory=$true ,Position=4,ValueFromPipeline)][int]$MessageID,
    [parameter(Mandatory=$true ,Position=5,ValueFromPipeline)][string]$DeploymentID
)

$CommonParams = @{
    StartTime = $((Get-Date).AddMinutes(15));
    EndTime   = $((Get-Date).AddMinutes(16).AddDays(15));
    emailTO = 'Chad@contoso.com';
    #emailCC = 'Chad.Simmons@CatapultSystems.com';
}

#region    ===== Debug: set values =====
If ($psISE) {
    $SSRSServer = 'ConfigMgrPri.contoso.com'
    $SiteServer = 'ConfigMgrPri.contoso.com'
    $SiteCode = 'LAB'
    $ReportPathRoot = 'ConfigMgr'
    $DeploymentID = 'LAB20017'  #Package/Program Deployment (Advertisement) ID
    $DeploymentID = 'Workstation Monthly Patching_9_2017-12-15 18:23:34' #Software Update Deployment Name
    $MessageID = '5800'
    Throw "Aborting!  In PowerShell ISE, this is intented to be run region by region"
}
#endregion ===== Debug: set values =====

#region    ######################### Functions #################################
################################################################################
################################################################################
Function Get-ScriptPath {
	#.Synopsis
	#   Get the folder of the script file
	#.Notes
	#   See snippet Get-ScriptPath.ps1 for excrutiating details and alternatives
	#   2017/07/25 by Chad@chadstech.net
	try {
		$script:ScriptPath = Split-Path -Path $((Get-Variable MyInvocation -Scope 1 -ErrorAction SilentlyContinue).Value).MyCommand.Path -Parent
	} catch {
		If ($psISE -and [string]::IsNullOrEmpty($script:ScriptPath)) {
			$script:ScriptPath = Split-Path $psISE.CurrentFile.FullPath -Parent #this works in psISE and psISE functions
		}
	}
	Write-Verbose "Function Get-ScriptPath: ScriptPath is $($script:ScriptPath)"
	Return $script:ScriptPath
}
Function Get-ScriptName {
	#.Synopsis  Get the name of the script file
	#.Notes
	#   See snippet Get-ScriptPath.ps1 for excrutiating details and alternatives
	#   2017/07/25 by Chad@chadstech.net

	If ($psISE) {
		$script:ScriptName = Split-Path $psISE.CurrentFile.FullPath -Leaf #this works in psISE and psISE functions
	} else {
		$script:ScriptName = ((Get-Variable MyInvocation -Scope 1 -ErrorAction SilentlyContinue).Value).MyCommand.Name
	}
	$script:ScriptBaseName = [System.IO.Path]::GetFileNameWithoutExtension($script:ScriptName)
	Write-Verbose "Function Get-ScriptName: ScriptName is $($script:ScriptName)"
	Write-Verbose "Function Get-ScriptName: ScriptBaseName is $($script:ScriptBaseName)"
	return $script:ScriptName
}
Function Get-CurrentLineNumber {
    If ($psISE) {
        $script:CurrentLine = $psISE.CurrentFile.Editor.CaretLine
    } else {
        $script:CurrentLine = $MyInvocation.ScriptLineNumber
    }
    return $script:CurrentLine
}
Function Get-CurrentFunctionName {
   (Get-Variable MyInvocation -Scope 1).Value.MyCommand.Name
}
Function Write-CMEvent {
	#.Synopsis Write a log entry in CMtrace format
	#.Notes    2017/05/16 by Chad@chadstech.net - based on Ryan Ephgrave's CMTrace Log Function @ http://www.ephingadmin.com/powershell-cmtrace-log-function
	#.Example  Write-CMEvent -LogFile $LogFile
	#.Example  Write-CMEvent -Message "This is a normal message" -LogFile $LogFile -Console
	#.Example  Write-CMEvent -Message "This is a normal message" -ErrorMessage $Error -LogFile $LogFile -Console
	#.Example  Write-CMEvent -Message "This is a warning" -Type Warn -Component "Test Component" -LogFile $LogFile
	#.Example  Write-CMEvent -Message "This is an Error!" -Type Error -Component "My Component" -LogFile $LogFile
	#.Parameter Message
	#	The message to write
	#.Parameter Type
	#	The type of message Information/Info/1, Warning/Warn/2, Error/3
	#.Parameter Component
	#	The source of the message being logged.  Typically the script name or function name.
	#.Parameter LogFile
	#	The file the message will be logged to
	#.Parameter Console
	#	Display the Message in the console
    Param (
		[Parameter(Mandatory = $true)]$Message,
		[ValidateSet('Error','Warn','Warning','Info','Information','1','2','3')][string]$Type,
		$Component = $script:ScriptName, #$($MyInvocation.MyCommand.Name), #Default to ScriptName
        $LogFile = $script:LogFile, #"$env:WinDir\Logs\Scripts\$([IO.Path]::ChangeExtension($(Split-Path $(If ($PSCommandPath) { $PSCommandPath } else { $psISE.CurrentFile.FullPath }) -Leaf),'.log'))",
		[switch]$Console
	)
	Switch ($Type) {
		{ @('3', 'Error') -contains $_ } { $intType = 3 } #3 = Error (red)
		{ @('2', 'Warn', 'Warning') -contains $_ } { $intType = 2 } #2 = Warning (yellow)
        Default { $intType = 1 } #1 = Normal
	}
	If ($Component -eq $null) {$Component = ' '} #Must not be null
	try { #write log file message
		"<![LOG[$Message]LOG]!><time=`"$(Get-Date -Format "HH:mm:ss.ffffff")`" date=`"$(Get-Date -Format "MM-dd-yyyy")`" component=`"$Component`" context=`"`" type=`"$Type`" thread=`"`" file=`"`">" | Out-File -Append -Encoding UTF8 -FilePath $LogFile
	} catch { Write-Error "Failed to write to the log file '$LogFile'" }
	If ($Console) { Write-Output $Message } #write to console if enabled
}; Set-Alias -Name 'Write-LogMessage' -Value 'Write-CMEvent' -Description 'Log a message in CMTrace format'
Function Start-Script ($LogFile) {
	$script:ScriptStartTime = Get-Date
	$script:ScriptPath = Get-ScriptPath
	$script:ScriptName = Get-ScriptName
	#$script:Console = $true
	#$script:EventLog = $true

	#if the LogFile is undefined set to <ScriptPath>\<ScriptName>.log
	If ([string]::IsNullOrEmpty($LogFile)) {
		$script:LogFile = "$script:ScriptPath\$([System.IO.Path]::GetFileNameWithoutExtension($script:ScriptName)).log"
	} else { $script:LogFile = $LogFile }

	#if the LogFile folder does not exist, create the folder
	Set-Variable -Name LogPath -Value $(Split-Path -Path $script:LogFile -Parent) -Description 'The folder/directory containing the log file' -Scope Script
	If (!(Test-Path $LogPath)) { New-Item -Path $LogPath -ItemType Directory -Force}

	Write-LogMessage -Message "==================== SCRIPT START ====================" -Component $script:ScriptName -Console
	Write-Output "Logging to $script:LogFile"
}
Function Stop-Script ($ReturnCode) {
	Write-LogMessage -Message "Exiting with return code $ReturnCode"
	$ScriptEndTime = Get-Date
	$ScriptTimeSpan = New-TimeSpan -Start $script:ScriptStartTime -end $ScriptEndTime #New-TimeSpan -seconds $(($(Get-Date)-$StartTime).TotalSeconds)
	Write-LogMessage -Message "Script Completed in $([math]::Round($ScriptTimeSpan.TotalSeconds)) seconds, started at $(Get-Date $script:ScriptStartTime -Format 'yyyy/MM/dd hh:mm:ss'), and ended at $(Get-Date $ScriptEndTime -Format 'yyyy/MM/dd hh:mm:ss')" -Console
	Write-LogMessage -Message "==================== SCRIPT COMPLETE ====================" -Component $script:ScriptName -Console
	Exit $ReturnCode
}
################################################################################
################################################################################
#endregion ######################### Functions #################################


#region    ######################### Initialization ############################
#If ([string]::IsNullOrEmpty($LogDir)) { $LogDir = "$env:WinDir\Logs" }
If ([string]::IsNullOrEmpty($LogDir)) { $LogDir = 'E:\Logs\ConfigMgr Scripts' }
$script:ScriptPath = Get-ScriptPath
Start-Script -LogFile "$LogDir\$([System.IO.Path]::GetFileNameWithoutExtension($(Get-ScriptName))).log"
Write-LogMessage -Message "Script Parameters: $($PSBoundParameters | Out-String)"
Write-LogMessage -Message "DeploymentID: $DeploymentID"
$Progress = @{Activity = "$script:ScriptName..."; Status = "Initializing..."} ; Write-Progress @Progress
#endregion ######################### Initialization ############################


#region    ######################### Main Script ###############################

If ($SiteCode.Length -ne 3) { #$PSBoundParameters.ContainsKey('SiteCode') -eq
    $SiteCode = (Get-WmiObject -ComputerName $SiteServer -Namespace "root\SMS" -ClassName "SMS_ProviderLocation" -Property "SiteCode").SiteCode
}
$CommonParams.Add('SiteCode',$SiteCode)
$CommonParams.Add('SSRSServer',$SSRSServer)
$CommonParams.Add('SiteServer',$SiteServer)
$CommonParams.Add('ReportPathRoot',$ReportPathRoot)


Write-LogMessage -Message "Common Parameters: $($CommonParams | Out-String)"

Switch ($MessageID) {
    30226 { # User created an Application Deployment
        #=== Status Filter Rule ===
        #Name: Create Report Subscription (Application Deployment)
        #Component: Microsoft.ConfigurationManagement.exe
        #Message Type: Audit
        #Message ID: 30226
        #Source: SMS Provider
        #Severity: Informational
        #Run a Program: "C:\Windows\System32\WindowsPowerShell\v1.0\PowerShell.exe" -ExecutionPolicy Bypass -NoProfile -File "E:\Scripts\New-SSRS_Subscription_FromCMEvent.ps1" -SSRSServer Bourne.FHLB.com -SiteServer %sitesvr -SiteCode %sc -MessageID %msgid -DeploymentID "ApplicationName:%msgis01 CollectionID:%msgis02"
        #=== Status Message Info ===
        #Description: User "FHLB\ConfigMgrSU" created a deployment of application "Power BI Desktop" to collection "NULL".
        #Properties: User Name : FHLB\ConfigMgrSU
        #=== Example Parameters ===
        #-DeploymentID "ApplicationName:Power BI Desktop CollectionName:NULL"

        $ApplicationName = $($DeploymentID -Split ' CollectionName:' | Select -First 1) -Split 'ApplicationName:' | Select -Last 1
        $CollectionName = $DeploymentID -Split ' CollectionName:' | Select -Last 1
        $Deployment = (Get-WmiObject -ComputerName $SiteServer -Namespace "root\SMS\Site_$SiteCode" -Query "SELECT AssignmentID FROM SMS_ApplicationAssignment WHERE AssignmentType=2 and ApplicationName='$ApplicationName' and CollectionName='$CollectionName'")
        $CommonParams.Add('AdvertisementID',$Deployment.AssignmentID)

        #Create an SSRS Email Subscription for the report "All application deployments (basic)"
        $ScriptFile = "$script:ScriptPath\New-SSRS_EmailSubscription_ApplicationDeployment.ps1"
        #Write-LogMessage -Message "Running '$ScriptFile' with -AdvertisementID $DeploymentID plus splatted parameters from CommonParams"
        #& "$ScriptFile" @CommonParams
        #Write-LogMessage -Message "$ScriptFile completed with return code $LastExitCode"

        Write-LogMessage -Message "Creating Parameter file '$ScriptFile.xml' for Scheduled Task"
        $CommonParams | Export-Clixml -Path "$ScriptFile.xml"
        Write-LogMessage -Message "Calling Scheduled Task Running '$ScriptFile CommonParams -AdvertisementID $DeploymentID'"
        #  Runs -NoProfile -ExecutionPolicy Bypass -File "E:\Scripts\New-SSRS_EmailSubscription_ApplicationDeployment.ps1" -AdvertisementID "E:\Scripts\New-SSRS_EmailSubscription_ApplicationDeployment.ps1.xml" -AdvertisementIDisXML
        Start-ScheduledTask -TaskName New-SSRS_EmailSubscription_ApplicationDeployment -ErrorVariable ReturnCode
        Write-LogMessage -Message "Scheduled Task execution error variable [$ReturnCode]"
        #TODO: Add error handling
        #wait for the scheduled task to complete
        Start-Sleep -Seconds 5

    }
    30006 { #Package/Program Deployment was created
        #=== Status Filter Rule ===
        #Name: Create Report Subscription (Package Deployment)
        #Component: Microsoft.ConfigurationManagement.exe
        #Message Type: Audit
        #Message ID: 30006
        #Run a Program: "C:\Windows\System32\WindowsPowerShell\v1.0\PowerShell.exe" -ExecutionPolicy Bypass -NoProfile -File "E:\Scripts\New-SSRS_Subscription_FromCMEvent.ps1" -SSRSServer Bourne.FHLB.com -SiteServer %sitesvr -SiteCode %sc -MessageID %msgid -DeploymentID %msgis02
        #=== Status Message Info ===
        #Description: User "FHLB\ConfigMgrSU" created a deployment of application "Power BI Desktop" to collection "NULL".
        #Properties: User Name : FHLB\ConfigMgrSU
        #=== Example Parameters ===
        #-DeploymentID DAL2002B

        $CommonParams.Add('AdvertisementID',$DeploymentID)
        #Create an SSRS Email Subscription for the report "Status of a specified package and program deployment"
        $ScriptFile = "$script:ScriptPath\New-SSRS_EmailSubscription_PackageDeployment.ps1"
        #Write-LogMessage -Message "Running '$ScriptFile' with -AdvertisementID $DeploymentID plus splatted parameters from CommonParams"
        #& "$ScriptFile" @CommonParams
        #Write-LogMessage -Message "$ScriptFile completed with return code $LastExitCode"

        Write-LogMessage -Message "Creating Parameter file '$ScriptFile.xml' for Scheduled Task"
        $CommonParams | Export-Clixml -Path "$ScriptFile.xml"
        Write-LogMessage -Message "Calling Scheduled Task Running '$ScriptFile CommonParams -AdvertisementID $DeploymentID'"
        #  Runs -NoProfile -ExecutionPolicy Bypass -File "E:\Scripts\New-SSRS_EmailSubscription_PackageDeployment.ps1" -Advertisement "E:\Scripts\New-SSRS_EmailSubscription_PackageDeployment.ps1.xml" -AdvertisementIDisXML
        Start-ScheduledTask -TaskName New-SSRS_EmailSubscription_PackageDeployment -ErrorVariable ReturnCode
        Write-LogMessage -Message "Scheduled Task execution error variable [$ReturnCode]"
        #TODO: Add error handling
        #wait for the scheduled task to complete
        Start-Sleep -Seconds 5
    }
    30008 { #Package/Program Deployment was deleted
        #This won't work since it was already deleted
        #$CMDeployment = Get-CMDeployment -DeploymentId $AdvertisementID
        #. "E:\Scripts\Delete-SSRS_Subscription.ps1"
    }
    30196 { # User Created a Software Update Group Deployment
        #NOTE: Message ID 5800 runs after 30196, thus this is really a duplicate

        #Message ID 30196, Component Microsoft.ConfigurationManagement.exe, System BOURNE.fhlb.com, Type Audit, Source SMS Provider, Severity Information,
        #User "FHLB\ConfigMgrSU" created updates assignment 16777484 ({8969F490-87C5-489C-9D13-4850E3D84F80}).
        #User Name : FHLB\ConfigMgrSU
        $CommonParams.Add('AdvertisementID',$DeploymentID)

        #Create an SSRS Email Subscription for the report "Compliance 1 - Overall compliance"
        $ScriptFile = "$script:ScriptPath\New-SSRS_EmailSubscription_Compliance_1_-_Overall compliance.ps1"
        Write-LogMessage -Message "Creating Parameter file '$ScriptFile.xml' for Scheduled Task"
        $CommonParams | Export-Clixml -Path "$ScriptFile.xml"

        #Create an SSRS Email Subscription for the report "States 4 - Computers in specific states for a deployment (custom)"
        $CommonParams.Add('ComplianceState','non-Compliant')
        $ScriptFile = "$script:ScriptPath\New-SSRS_EmailSubscription_States_4_-_Computers in specific states for a deployment (custom).ps1"
        Write-LogMessage -Message "Creating Parameter file '$ScriptFile.xml' for Scheduled Task"
        $CommonParams | Export-Clixml -Path "$ScriptFile.xml"

        $ScheduledTaskName = 'New-SSRS_EmailSubscription_SoftwareUpdateDeployment'
        Write-LogMessage -Message "Calling Scheduled Task '$ScheduledTaskName'"
        Start-ScheduledTask -TaskName "$ScheduledTaskName" -ErrorVariable ReturnCode
        Write-LogMessage -Message "Scheduled Task execution error variable [$ReturnCode]"
        #TODO: Add error handling
        #wait for the scheduled task to complete
        Start-Sleep -Seconds 10
    }
    30198 { # Delete a Software Update Group Deployment
        #Message ID 30198, Component Microsoft.ConfigurationManagement.exe, System BOURNE.fhlb.com, Type Audit, Source SMS Provider, Severity Information,
        #User "FHLB\ConfigMgrSU" deleted updates assignment 16777483 ({4AC5D2CE-90CB-4B12-BF40-40483A820331}).
        #User Name : FHLB\ConfigMgrSU
    }
    30219 { # Create a Software Update Group
        #Message ID 30219, Component Microsoft.ConfigurationManagement.exe, System BOURNE.fhlb.com, Type Audit, Source SMS Provider, Severity Information,
        #User "FHLB\ConfigMgrSU" created authorization list "16821607" (CI_UniqueID=ScopeId_D955DB0D-84DB-4C03-B5F6-6E4C056B0BED/AuthList_A19ACEE5-D157-4F3B-A669-F0F49EB5796B, CIVersion=1).
        #User Name : FHLB\ConfigMgrSU
    }
    5800 { # System Created a Software Update Group Deployment
        #=== Status Filter Rule ===
        #Name: Create Report Subscription ((SUG Deployment)
        #Component: SMS_OBJECT_REPLICATION_MANAGER
        #Message Type: Milestone
        #Message ID: 5800
        #Run a Program: "C:\Windows\System32\WindowsPowerShell\v1.0\PowerShell.exe" -ExecutionPolicy Bypass -NoProfile -File "E:\Scripts\New-SSRS_Subscription_FromCMEvent.ps1" -SSRSServer Bourne.FHLB.com -SiteServer %sitesvr -SiteCode %sc -MessageID %msgid -DeploymentID "%msgis01"
        #=== Status Message Info ===
        #Description: CI Assignment Manager successfully processed new CI Assignment Workstation Monthly Patching_2_2017-10-31 08:53:13.
        #Properties: CI Assignment ID : {0019cbd9-6cb9-41a5-a4fc-7e56e853927c}
        #=== Example Parameters ===
        #-DeploymentID "Workstation Monthly Patching_2_2017-12-15 18:24:17"
        <# DEBUG:
            $DeploymentID = 'Workstation Monthly Patching_2_2017-12-15 18:24:17'
            $CommonParams.Remove('AdvertisementID')
            $CommonParams.Remove('ComplianceState')
        #>
        $ScheduledTaskName = 'New-SSRS_EmailSubscription_SoftwareUpdateDeployment'

        $Deployments = @(Get-WmiObject -ComputerName $SiteServer -Namespace "root\SMS\Site_$SiteCode" -Query "SELECT AssignmentID FROM SMS_UpdatesAssignment WHERE AssignmentType=5 and AssignmentName='$DeploymentID'")
        $CommonParams.Add('AdvertisementID',$($($Deployments.AssignmentID) -join ','))

        #A ConfigMgr ADR can create multiple Software Update Group Deployments in a few seconds.
        #Wait up to 5 minutes for the Scheduled Task to complete so the configuration files are not overwritten
        $i=0
        While ((Get-ScheduledTask -TaskName $ScheduledTaskName).State -ne 'Ready' -and $i -le 300) {
            Start-Sleep -Seconds 5
            $i+=5
            Write-LogMessage -Message "Waiting 5 seconds for Scheduled Task '$ScheduledTaskName' to be Ready"
        }
        Write-LogMessage -Message "Scheduled Task '$ScheduledTaskName' is now $((Get-ScheduledTask -TaskName $ScheduledTaskName).State)"

        #Create an SSRS Email Subscription for the report "Compliance 1 - Overall compliance"
        $ScriptFile = "$script:ScriptPath\New-SSRS_EmailSubscription_Compliance_1_-_Overall compliance.ps1"
        Write-LogMessage -Message "Creating Parameter file '$ScriptFile.xml' for Scheduled Task"
        $CommonParams | Export-Clixml -Path "$ScriptFile.xml"

        #Create an SSRS Email Subscription for the report "States 4 - Computers in specific states for a deployment (custom)"
        $CommonParams.Add('ComplianceState','non-Compliant')
        $ScriptFile2 = "$script:ScriptPath\New-SSRS_EmailSubscription_States_4_-_Computers in specific states for a deployment (custom).ps1"
        Write-LogMessage -Message "Creating Parameter file '$ScriptFile2.xml' for Scheduled Task"
        $CommonParams | Export-Clixml -Path "$ScriptFile2.xml"


        Write-LogMessage -Message "Calling Scheduled Task '$ScheduledTaskName'"
        Start-ScheduledTask -TaskName "$ScheduledTaskName" -ErrorVariable ReturnCode
        If ($ReturnCode -ne $null) {
            Write-LogMessage -Message "Scheduled Task execution error variable [$ReturnCode]"
        } else {
            While ((Get-ScheduledTask -TaskName $ScheduledTaskName).State -ne 'Ready' -and $i -le 300) {
                Start-Sleep -Seconds 1
                $i+=1
                Write-LogMessage -Message "Waiting 1 second for Scheduled Task '$ScheduledTaskName' to Complete"
            }
            Write-LogMessage -Message "Scheduled Task '$ScheduledTaskName' is now $((Get-ScheduledTask -TaskName $ScheduledTaskName).State)"
            #$ScheduledTaskInfo = Get-ScheduledTaskInfo -TaskName "$ScheduledTaskName" -ErrorVariable ReturnCode
            #Write-LogMessage -Message "Scheduled Task completed with result [$($ScheduledTaskInfo.LastTaskResult)]" #this is NOT a return/exit/error/success code
        }
        If (Test-Path -Path "$ScriptFile.xml") { Remove-Item -Path "$ScriptFile.xml" }
        If (Test-Path -Path "$ScriptFile2.xml") { Remove-Item -Path "$ScriptFile2.xml" }
    }
    5802 { # System deleted a Software Update Group Deployment
        #Message ID 5802, Component SMS_OBJECT_REPLICATION_MANAGER, System BOURNE.fhlb.com, Type Milestone
        #CI Assignment Manager successfully removed CI Assignment Microsoft Software Updates - 2017-11-27 10:28:02 AM.
        #CI Assignment ID : {4AC5D2CE-90CB-4B12-BF40-40483A820331}
    }
    Default {
        Write-LogMessage -Message "Message ID not actionable"
        Stop-Script -ReturnCode 0
        Throw "MessageID $MessageID not recognized"
    }
}

#endregion ######################### Main Script ###############################
#region    ######################### Deallocation ##############################

If (Test-Path variable:LastExitCode) {
    Stop-Script -ReturnCode $LastExitCode
} else {
    Stop-Script -ReturnCode 0
}
#endregion ######################### Deallocation ##############################