<#
.SYNOPSIS
    New-SSRS_EmailSubscription_States 4 - Computers in specific states for a deployment [custom].ps1
    Creates SSRS Report Subscription using the SSRS Web Service
.LINK
    Based on https://github.com/gwalkey/SSRS_Subscriptions/blob/master/New-SSRS_Subscription.ps1
.DESCRIPTION
    Creates SSRS Report Subscription using the SSRS Web Service

.EXAMPLE

#>

Param(
    [parameter(Mandatory=$false,Position=0,ValueFromPipeline)][ValidateNotNullOrEmpty()][string]$SSRSServer = 'localhost',
    [parameter(Mandatory=$false,Position=1,ValueFromPipeline)][ValidateNotNullOrEmpty()][string]$SiteServer = 'localhost',
    [parameter(Mandatory=$false,Position=2,ValueFromPipeline)][string]$SiteCode,
    [parameter(Mandatory=$true, Position=3,ValueFromPipeline)][string]$AdvertisementID,
    [parameter(Mandatory=$false,Position=4,ValueFromPipeline)][string]$ReportPathRoot = 'ConfigMgr',
    [parameter(Mandatory=$false,Position=5,ValueFromPipeline)][string]$emailTO = 'Chad.Simmons@contoso.com',
    [parameter(Mandatory=$false,Position=6,ValueFromPipeline)][string]$emailCC = 'Chad.Simmons@CatapultSystems.com',
    [parameter(Mandatory=$false,Position=7,ValueFromPipeline)][datetime]$StartTime = $(Get-Date).AddMinutes(15),
    [parameter(Mandatory=$false,Position=8,ValueFromPipeline)][datetime]$EndTime = $((Get-Date).AddDays(31)).AddMinutes(15),
    [parameter(Mandatory=$false,Position=6,ValueFromPipeline)][string]$ComplianceState,
    [parameter()][Switch]$AdvertisementIDisXML
)

#region    ===== Debug: set values =====
If ($psISE) {
    #Parameters
    #[string]$AdvertisementID = '16777484'
    [bool]$AdvertisementIDisXML = $true
    [string]$AdvertisementID = 'E:\Scripts\New-SSRS_EmailSubscription_States_4_-_Computers in specific states for a deployment (custom).ps1.xml'

    [datetime]$StartTime = $(Get-Date).AddMinutes(15)
    [datetime]$EndTime = $((Get-Date).AddDays(31)).AddMinutes(15)
    [string]$emailTO = 'Chad.Simmons@Contoso.com'
    [string]$emailCC = 'Chad.Simmons@CatapultSystems.com'
    [string]$SSRSServer = 'localhost'
    [string]$SiteServer = 'localhost'
    [string]$SiteCode = 'DAL'
    [string]$ReportPathRoot = 'ConfigMgr'
    [string]$ComplianceState = 'non-Compliant'
}
#endregion ===== Debug: set values =====

#region    ######################### Functions #################################
################################################################################
################################################################################
Function Get-ScriptPath {
	#.Synopsis
	#   Get the folder of the script file
	#.Notes
	#   See snippet Get-ScriptPath.ps1 for excruciating details and alternatives
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
	#   See snippet Get-ScriptPath.ps1 for excruciating details and alternatives
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
    If ($null -eq $Component) { $Component = ' ' } #Must not be null
	try { #write log file message
        "<![LOG[$Message]LOG]!><time=`"$(Get-Date -Format "HH:mm:ss.ffffff")`" date=`"$(Get-Date -Format "MM-dd-yyyy")`" component=`"$Component`" context=`"`" type=`"$intType`" thread=`"`" file=`"`">" | Out-File -Append -Encoding UTF8 -FilePath $LogFile
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

Function CreateSSRSSubscription {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)][string]$prmMatchData,
        [Parameter(Mandatory=$true)][string]$prmSchedule
    )

    ##DEBUG
    #[string]$prmMatchData=$myMatchData
    #[string]$prmSchedule=$myscheduleXml
    ##DEBUG END
    Write-Verbose "Report Parameter XML: $prmMatchData"
    Write-Verbose "Report Sechedule XML: $prmSchedule"

    # SSRS Server URI
    $ReportServerUri  = "http://$SSRSServer/ReportServer/ReportService2010.asmx"

    # Open Web Service Connection
    Remove-Variable -Name rs2010 -ErrorAction SilentlyContinue
    $rs2010 += New-WebServiceProxy -Uri $ReportServerUri -UseDefaultCredential;

    # Get Types from SSRS Webservice Namespace
    $type = $rs2010.GetType().Namespace

    # Define Object Types for Subscription property call
    # http://stackoverflow.com/questions/25984874/not-able-to-create-objects-in-powershell-for-invoking-a-web-service
    # http://stackoverflow.com/questions/32611187/using-complex-objects-via-a-web-service-from-powershell
    # This XML Fragment holds Three sections
    # 1) Extension Settings (Email or Fileshare, where, who etc)
    # 2) Schedule
    # 3) Report Parameters

    $ExtensionSettingsDataType = ($type + '.ExtensionSettings')
    $ActiveStateDataType = ($type + '.ActiveState')
    $ParmValueDataType = ($type + '.ParameterValue')

    # Create New ExtensionSettings Object based on Type
    $extSettings = New-Object ($ExtensionSettingsDataType)
    $AllReportParameters = New-Object ($ParmValueDataType)

    # Function Call parameters setup
    $extensionParams = @()
    $rptParamArray = @()

    # Load Subscription build parameters from an XML File with includes a section for the schedule
    [xml]$xml = $prmMatchData
    $xSubscription = $xml.Subscription
    $xExtensionSettings = $xSubscription.ExtensionSettings

    # Get more Report parameters
    #$report = [string]::Join("", $xSubscription.ReportPath, $xSubscription.ReportName)
    $report = $xSubscription.ReportPath+$xSubscription.ReportName
    $desc = $xSubscription.Description
    $event = $xSubscription.EventType
    $extSettings.Extension = $xExtensionSettings.DeliveryExtension

    # Get Schedule from a direct XML Definition
    $scheduleXml = $prmSchedule

    # Get the extension settings parameter values from the XML Fragment
    $xExtParams = $xExtensionSettings.ParameterValues.ParameterValue

    foreach ($p in $xExtParams) {
	    $param = New-Object ($ParmValueDataType)
	    $param.Name = $p.Name
	    $param.Value = $p.Value
	    $extensionParams += $param
    }
    # Build up object
    $extSettings.ParameterValues = $extensionParams

    # Get Actual Report Parameters from XML Fragment
    $ReportParameters= $xml.Subscription.ReportParameter.ParameterValue
    foreach ($rp in $ReportParameters) {
        $rparam = New-Object ($ParmValueDataType)
	    $rparam.Name = $rp.Name
	    $rparam.Value = $rp.Value
	    $rptParamArray += $rparam
    }
    # BuildUpObject from individual elements
    $AllReportParameters = $rptParamArray

    # Call the WebService
    try {
        $subscriptionID = $rs2010.CreateSubscription($report, $extSettings, $desc, $event, $scheduleXml, $AllReportParameters)
        Write-LogMessage -Message $("Created Subscription ID: {0}" -f $subscriptionID)
    } catch {
        Write-LogMessage -Message $("Exception: {0} Inner: {1}" -f $_.Exception.Message, $_.Exception.Message.InnerException) -Type Error
        Write-Error ("Exception: {0} Inner: {1}" -f $_.Exception.Message, $_.Exception.Message.InnerException)
        $error[0] | Format-List -force
        Stop-Script -ReturnCode $_.Exception.HResult
        Throw "Failed! $($error[0])"
    }
    If (Test-Path variable:rs2010) { Remove-Variable -Name rs2010 -ErrorAction SilentlyContinue }
}
################################################################################
################################################################################
#endregion ######################### Functions #################################


#region    ######################### Initialization ############################
#If ([string]::IsNullOrEmpty($LogDir)) { $LogDir = "$env:WinDir\Logs" }
$LogDir = 'E:\Logs\ConfigMgr Scripts'
Start-Script -LogFile "$LogDir\$([System.IO.Path]::GetFileNameWithoutExtension($(Get-ScriptName))).log"
Write-LogMessage -Message "Script Parameters: $($PSBoundParameters | Out-String)"
$Progress = @{Activity = "$script:ScriptName..."; Status = "Initializing..."} ; Write-Progress @Progress

If ($AdvertisementIDisXML -eq $true) {
    $AdvertisementIDFile = $AdvertisementID
   If (Test-Path -Path $AdvertisementIDFile) {
        $Parameters = Import-Clixml -Path "$AdvertisementIDFile"
        [datetime]$StartTime = $Parameters.Get_Item('StartTime')
        [datetime]$EndTime = $Parameters.Get_Item('EndTime')
        [string]$emailTO = $Parameters.Get_Item('emailTO')
        [string]$emailCC = $Parameters.Get_Item('emailCC')
        [string]$SSRSServer = $Parameters.Get_Item('SSRSServer')
        [string]$SiteServer = $Parameters.Get_Item('SiteServer')
        [string]$SiteCode = $Parameters.Get_Item('SiteCode')
        [string]$ReportPathRoot = $Parameters.Get_Item('ReportPathRoot')
        [string]$ComplianceState = $Parameters.Get_Item('ComplianceState')
        [string]$AdvertisementID = $Parameters.Get_Item('AdvertisementID') #overwrite the variable
   } else {
        Write-LogMessage -Message "Parameter file '$AdvertisementID' was not found" -Type Error
        Stop-Script -ReturnCode 2
   }
}
Write-LogMessage -Message "Imported Parameters: $($Parameters | Out-String)"

#endregion ######################### Initialization ############################


#region    ######################### Main Script ###############################
If ($SiteCode.Length -ne 3) { #$PSBoundParameters.ContainsKey('SiteCode') -eq
    $SiteCode = (Get-WmiObject -ComputerName $SiteServer -Namespace "root\SMS" -ClassName "SMS_ProviderLocation" -Property "SiteCode").SiteCode
}


ForEach ($AdvertID in $AdvertisementID.Split(',')) {

    $Deployment = @(Get-WmiObject -ComputerName $SiteServer -Namespace "root\SMS\Site_$SiteCode" -Query "SELECT * FROM SMS_DeploymentSummary WHERE AssignmentID='$AdvertID'")
    <#
    ==Software Update Group==
    ApplicationName     : Workstation Monthly Patching 2017-11-14 18:20:00
    AssignmentID        : 16777484
    CI_ID               : 16821546
    CollectionID        : DAL00083
    CollectionName      : NULL
    CreationTime        : 20171127163759.000000+***
    DeploymentID        : {8969F490-87C5-489C-9D13-4850E3D84F80}
    DeploymentTime      : 20171127103700.000000+***
    EnforcementDeadline : 20171204103700.000000+***
    FeatureType         : 5
    ModelName           : ScopeId_D955DB0D-84DB-4C03-B5F6-6E4C056B0BED/AuthList_359b0ea4-58e6-4b5e-a431-36addca02181
    ObjectTypeID        : 200
    PolicyModelID       : 16821482
    SecuredObjectId     : {8969F490-87C5-489C-9D13-4850E3D84F80}
    SoftwareName        : Workstation Monthly Patching 2017-11-14 18:20:00


    Report Parameters:
    ------------------------------
    DEPLOYMENTID {8969F490-87C5-489C-9D13-4850E3D84F80}
    ComplianceState non-Compliant
    #>

    If ($Deployment.count -ne 1) {
        Write-LogMessage -Message "Aborting! Found $($Deployment.count) deployments but expected 1" -Type Error
        Stop-Script -ReturnCode $Error[0].Exception.HResult
        Throw "Aborting! Found $($Deployment.count) deployments but expected 1"
    }
    #Try {
    #    $Deployment | Add-Member -MemberType NoteProperty -Name 'PackageID' -Value $(Get-WmiObject -ComputerName $SiteServer -Namespace "root\SMS\Site_$SiteCode" -ClassName 'SMS_Package' -Filter "Name='$($Deployment.TargetName)'" -Property 'PackageID').PackageID
    #    Write-LogMessage -Message "Deployment found $($Deployment | Format-List [a-zA-Z]* | Out-String)"
    #} catch {
    #    Write-LogMessage -Message "Aborting! Failed to get Package ID for Package Name $($Deployment.TargetName)" -Type Error
    #    Write-Verbose -Message "$($Error[0] | Format-List -Force)"
    #    Stop-Script -ReturnCode $Error[0].Exception.HResult
    #    Throw "Aborting! Failed to get Package ID for Package Name $($Deployment.TargetName)"
    #}


    [string]$ReportName='States 4 - Computers in specific states for a deployment (custom)'
    [string]$ReportPath="/$ReportPathRoot/Custom Reports/Software Updates"
    [string]$SubscriptionDescription = "Deployment - $($Deployment.SoftwareName) - " + $($Deployment.CollectionID) + " - " + $ComplianceState
    [string]$SubscriptionComment     = "This report will run from $StartTime to $EndTime`r`nSoftware Update Group: $($Deployment.SoftwareName) `r`nComplianceState: $ComplianceState `r`nCollection: $($Deployment.CollectionName) ($($Deployment.CollectionID))`r`nAdvertisementID: $($AdvertisementID)"

    $myMatchData =
    "<Subscription>
	    <ReportName>/$ReportName</ReportName>
	    <ReportPath>$ReportPath</ReportPath>
	    <Description>$SubscriptionDescription</Description>
	    <EventType>TimedSubscription</EventType>
	    <ExtensionSettings>
		    <DeliveryExtension>Report Server Email</DeliveryExtension>
		    <ParameterValues>
			    <ParameterValue>
				    <Name>TO</Name>
				    <Value>$emailTO</Value>
			    </ParameterValue>
			    <ParameterValue>
				    <Name>CC</Name>
				    <Value>$emailCC</Value>
			    </ParameterValue>
			    <ParameterValue>
				    <Name>IncludeReport</Name>
				    <Value>True</Value>
			    </ParameterValue>
			    <ParameterValue>
				    <Name>RenderFormat</Name>
				    <Value>MHTML</Value>
			    </ParameterValue>
			    <ParameterValue>
				    <Name>IncludeLink</Name>
				    <Value>True</Value>
			    </ParameterValue>
			    <ParameterValue>
				    <Name>Subject</Name>
				    <Value>$SubscriptionDescription</Value>
			    </ParameterValue>
			    <ParameterValue>
				    <Name>Comment</Name>
				    <Value>$SubscriptionComment</Value>
			    </ParameterValue>
			    <ParameterValue>
				    <Name>Priority</Name>
				    <Value>NORMAL</Value>
			    </ParameterValue>
		    </ParameterValues>
	    </ExtensionSettings>

	    <ReportParameter>
		    <ParameterValue>
			    <Name>DEPLOYMENTID</Name>
			    <Value>$($Deployment.DeploymentID)</Value>
		    </ParameterValue>
		    <ParameterValue>
			    <Name>ComplianceState</Name>
			    <Value>$ComplianceState</Value>
		    </ParameterValue>
	    </ReportParameter>
    </Subscription>"

    #[string]$myscheduleXml =
    #"
    #<ScheduleDefinition>
    #    <StartDateTime>$myYear-$((get-date).Month)-15T06:00:00.000-04:00</StartDateTime>
    #</ScheduleDefinition>
    #"
    [string]$myscheduleXml =
    "
    <ScheduleDefinition>
        <StartDateTime>$(Get-Date -Date $StartTime -Format 'yyyy-MM-ddTHH:mm:ss.fffzzz')</StartDateTime>
        <EndDate>$(Get-Date -Date $EndTime -Format 'yyyy-MM-ddTHH:mm:ss.fffzzz')</EndDate>
        <WeeklyRecurrence>
        <WeeksInterval>1</WeeksInterval>
        <DaysOfWeek>
            <Monday>true</Monday>
            <Tuesday>true</Tuesday>
            <Wednesday>true</Wednesday>
            <Thursday>true</Thursday>
            <Friday>true</Friday>
        </DaysOfWeek>
        </WeeklyRecurrence>
    </ScheduleDefinition>
    "
    CreateSSRSSubscription -prmMatchData $myMatchData -prmSchedule $myscheduleXml
    Write-LogMessage -Message "Created an SSRS Email Subscription for report '$ReportName', PackageID $($Deployment.PackageID), and CollectionID $($Deployment.CollectionID) scheduled to run weekdays until $EndTime"
}

#endregion ######################### Main Script ###############################
#region    ######################### Deallocation ##############################

If ($AdvertisementIDisXML -eq $true -and $(Test-Path -Path $AdvertisementIDFile) -eq $true) {
    Remove-Item -Path $AdvertisementIDFile
}

Stop-Script -ReturnCode 0
#endregion ######################### Deallocation ##############################