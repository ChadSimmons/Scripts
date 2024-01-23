#.Synopsis
#   Get-MECMDistributionPointDetails.ps1
#   Get ConfigMgr Distribution Point role and drive detailed properties
param (
	[parameter(Mandatory=$true)][string]$SiteCode = 'LAB',
	[parameter()][string[]]$DistributionPoint
)


Function Convert-CMScheduleToArray ($ScheduleString) {
    #$ScheduleString = '1523568894'
    #$ScheduleString = ''
    $CMSchedule = Convert-CMSchedule -ScheduleString $ScheduleString
    $Schedule = @("String=$ScheduleString")
    $Schedule += @("SmsProviderObjectPath=$($CMSchedule.SmsProviderObjectPath)")
    If($CMSchedule.SmsProviderObjectPath -eq 'SMS_ST_RecurInterval') {
        $Schedule += @("DayDuration=$($CMSchedule.DayDuration)")
        $Schedule += @("DaySpan=$($CMSchedule.DaySpan)")
        $Schedule += @("HourDuration=$($CMSchedule.HourDuration)")
        $Schedule += @("HourSpan=$($CMSchedule.HourSpan)")
        $Schedule += @("IsGMT=$($CMSchedule.IsGMT)")
        $Schedule += @("MinuteDuration=$($CMSchedule.MinuteDuration)")
        $Schedule += @("MinuteSpan=$($CMSchedule.MinuteSpan)")
        $Schedule += @("StartTime=$($CMSchedule.StartTime)")
    } ElseIf ($CMSchedule.SmsProviderObjectPath -eq 'SMS_ST_RecurWeekly') {
        $Schedule += @("Day=$($CMSchedule.Day)")
        $Schedule += @("DayDuration=$($CMSchedule.DayDuration)")
        $Schedule += @("ForNumberOfWeeks=$($CMSchedule.ForNumberOfWeeks)")
        $Schedule += @("HourDuration=$($CMSchedule.HourDuration)")
        $Schedule += @("IsGMT=$($CMSchedule.IsGMT)")
        $Schedule += @("MinuteDuration=$($CMSchedule.MinuteDuration)")
        $Schedule += @("StartTime=$($CMSchedule.StartTime)")
    } Else {
    }
    Return $Schedule
}

Push-Location -Path "$SiteCode`:"
If ($DistributionPoint.count -eq 0) {
	$DistributionPoint = @((Get-CMDistributionPoint -SiteCode $SiteCode).NALPath.split('\')[2])
}

$ProgressActivity = "ConfigMgr Distribution Point drive details: Processing server $Count of $($DistributionPoint.count)"
Write-Progress -Activity $ProgressActivity -Status "$DPServer... getting DP object"

$DPDriveInfo = Get-CMDistributionPointDriveInfo | Select NALPath, Drive, BytesTotal, BytesFree, ComputerName, GBTotal, GBFree, ConttentLibPriority, ObjectType, PercentFree, PkgSharePriority, Status, SiteCode; ForEach ($DP in $DPDriveInfo) { $DP.GBTotal = [math]::Round($DP.BytesTotal/1MB,1); $DP.GBFree = [math]::Round($DP.BytesFree/1MB,1); $DP.ComputerName = $DP.NALPath.split('\')[2];}

$Count = 0
#$DPsInfo +=
ForEach ($DPServer in $DistributionPoint) {
    $Count++
	$ProgressActivity = "ConfigMgr Distribution Point details: Processing server $Count of $($DistributionPoint.count)"
    Write-Progress -Activity $ProgressActivity -Status "$DPServer... getting DP object"
    $DP = Get-CMDistributionPoint -SiteCode $SiteCode -SiteSystemServerName $DPServer
    $DPInfo = [ordered]@{
        ComputerName = $DP.NALPath.split('\')[2]
        RoleCount = $DP.RoleCount
        RoleName = $DP.RoleName
        ServerState = $DP.ServerState
        ServiceWindows = $DP.ServiceWindows
        SiteSystemStatus = $DP.SiteSystemStatus
        #SSLstate = $DP.SslState
        Type = $DP.Type
    }
    ForEach ($Prop in $DP.EmbeddedProperties.Keys) {
        #"$($Prop) -> $($DPs.EmbeddedProperties["$Prop"])"
        $DPInfo.Add("$Prop",$DP.EmbeddedProperties["$Prop"].Value)
    }
    $DPInfo.ADSiteName = $DP.EmbeddedProperties['ADSiteName'].Value1
    $DPInfo.AvailableContentLibDrivesList = $DP.EmbeddedProperties['AvailableContentLibDrivesList'].Value1
    $DPInfo.AvailablePkgShareDrivesList = $DP.EmbeddedProperties['AvailablePkgShareDrivesList'].Value1
    $DPInfo.CertificateExpirationDate = $DP.EmbeddedProperties['CertificateExpirationDate'].Value #convert to date
    $DPInfo.DPMonSchedule = $DP.EmbeddedProperties['DPMonSchedule'].Value1 #may be more
    $DPInfo.IdentityGUID = $DP.EmbeddedProperties['IdentityGUID'].Value1 #may be more
    $DPInfo.IPSubnets = $DP.EmbeddedProperties['IPSubnets'].Value1 #may be more
    $DPInfo.LastIISConfigCheckTime = $DP.EmbeddedProperties['LastIISConfigCheckTime'].Value #convert to date
    $DPInfo.'Server Remote Name' = $DP.EmbeddedProperties['Server Remote Name'].Value1
    $DPInfo.'Site Info' = $DP.EmbeddedProperties['Site Info'].Value1
    $DPInfo.Version = $DP.EmbeddedProperties['Version'].Value1

    $DPInfo.DPMonSchedule = Convert-CMScheduleToArray -ScheduleString $DPInfo.DPMonSchedule
    $DPInfo.LastIISConfigCheckTime = Convert-CMScheduleToArray -ScheduleString $DPInfo.LastIISConfigCheckTime

    $DPInfo
}
Pop-Location

#$DPsInfo
$DPDriveInfo #| Select ComputerName, Drive, GBTotal, GBFree
Write-Progress -Activity $ProgressActivity  -Status "Done"; Start-Sleep -Seconds 1
Write-Progress -Activity $ProgressActivity  -Status "Done" -Completed