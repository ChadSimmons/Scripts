<#
#Run Monday morning
PowerShell.exe -NoProfile -ExecutionPolicy Bypass -File D:\Scripts\Set-DPRateLimits2.ps1 -AllDPs -Enable $True -ApplyChanges -SiteServer MSCSCCM001.ad.contoso.com -SiteCode P01
PowerShell.exe -NoProfile -ExecutionPolicy Bypass -File D:\Scripts\Set-DPRateLimits2.ps1 -DPFQDN @("MSCSCCM003.AD.contoso.COM","MSCSCCM009.AD.contoso.COM") -Enable $False -ApplyChanges -SiteServer MSCSCCM001.ad.contoso.com -SiteCode P01

#Run Friday evening
PowerShell.exe -NoProfile -ExecutionPolicy Bypass -File D:\Scripts\Set-DPRateLimits2.ps1 -AllDPs -ScheduleAll90 -Enable $True -ApplyChanges -SiteServer MSCSCCM001.ad.contoso.com -SiteCode P01
PowerShell.exe -NoProfile -ExecutionPolicy Bypass -File D:\Scripts\Set-DPRateLimits2.ps1 -DPFQDN @("MSCSCCM003.AD.contoso.COM","MSCSCCM009.AD.contoso.COM") -Enable $False -ApplyChanges -SiteServer MSCSCCM001.ad.contoso.com -SiteCode P01
#>

<# 
.SYNOPSIS 
   Enable or Diable Rate Limits for SCCM Distribution point. 
.DESCRIPTION 
   Enable or Diable Rate Limits for SCCM Distribution point. This is set on the Rate Limits Tab of the Distribution point Properties
   in the Console. The equivilent action in the gui to enable is to click the "Limited to specified maximun transfer rated by hour:" 
   radio button and to set the Limiting Schedule. The equivilent action in the gui to disable is to click the 
   "Unlimited when sending to this destination" radio button.
   Please note that in the GUI Pulse mode is configured on same tab. This script does not configure Pulse mode.
.PARAMETER SiteServer 
   Server name of the Primary Site. Required
.PARAMETER SiteCode 
   Site Code of the Primary Site used in the -SiteServer parameter. Required
.PARAMETER dpFQDN 
   Fully Qualiied Domain Name of the Distribution Point. Required
.PARAMETER AllDPs
    Use this switch instead of a DPFQDN to affect all Distribution Points
.PARAMETER Enable 
   Used to specify is the Rate limit should be enabled or disabled. Only accepts $true or $false
   This is an optional parameter. By default it will be enabled.
.PARAMETER ScheduleAll90 
   Used to specify is the Rate limit should be 90% for all hours
.PARAMETER RateLimitingSchedule
   An array used to specify is the Rate limit should be customized for normal business hours
   - 100% 12 AM -  5 AM
   -  25%  6 AM -  6 PM
   - 100%  7 PM - 11 PM
.EXAMPLE
   .\Set-DPRateLimits.ps1 -DPFQDN MSCSCCM003.ad.contoso.com -SecheduleAll90
    This will enable rate limits and set all time frames to 90% 
.EXAMPLE
   .\Set-DPRateLimits.ps1 -DPFQDN MSCSCCM003.ad.contoso.com
    This will enable default rate limits 
.EXAMPLE
   .\Set-DPRateLimits.ps1 -SiteServer MSCSCCM001 -SiteCode P01 -DPFQDN MSCSCCM003.ad.contoso.com
    This will enable default rate limits 
.EXAMPLE
   Set-DPRateLimits -SiteServer MSCSCCM001 -SiteCode P01 -DPFQDN MSCSCCM003.ad.contoso.com -Enable $false
   This will disable rate limits
.Notes
	Author: Jon Warnken jon.warnken@gmail.com
	Revisions:
		1.0 06/20/2014 - Original creation. SPecial thanks to Keith Thornley for sending me the orginal function
		1.1 06/23/2014 - Added comment-based help 
        1.2 2016/04/15 - change from a function to a stand-alone script - Chad.Simmons@CatapultSystems.com
#> 
[CmdletBinding()]

param (
[Parameter(Mandatory=$false)] [string]$SiteServer = 'MSCSCCM001.ad.contoso.com',
[Parameter(Mandatory=$false)] [string]$SiteCode = 'P01',
[Parameter(Mandatory=$false)] [string[]]$DPFQDN,
[Parameter(Mandatory=$false)] $Enable=$True,
[Parameter(Mandatory=$false)] [Switch]$AllDPs,
[Parameter(Mandatory=$false)] [Switch]$ApplyChanges,
[Parameter(Mandatory=$false)] [Switch]$ScheduleAll90,
#Define a percentage, in an array with 1 value per hour starting at midnight
#the rate limit below is 25% 6am - 7pm and 100% all other times
[Parameter(Mandatory=$false,Position=5)]
[array]$RateLimitingSchedule = @(100,100,100,100,100,100,25,25,25,25,25,25,25,25,25,25,25,25,25,100,100,100,100,100)

) 

If ($ScheduleAll90) { [array]$RateLimitingSchedule = @(90,90,90,90,90,90,90,90,90,90,90,90,90,90,90,90,90,90,90,90,90,90,90,90) }

If ($AllDPs) { 
    #Get All Distribution Points
    $DPs=@(Get-WmiObject -Computername $siteserver -namespace "root\sms\site_$sitecode" -query "select DesSiteCode from SMS_SCI_address").DesSiteCode
} else {
    $DPs=@($DPFQDN)
}

ForEach ($DPFQDN in $DPs) {
	#$DPFQDN = $DPFQDN + "|MS_LAN"
    $dp = gwmi -Computername $siteserver -namespace "root\sms\site_$sitecode" -query "select * from SMS_SCI_address where itemname = '$DPFQDN|MS_LAN'" 
    If ($dp.DesSiteCode -eq $DPFQDN) {
        Write-Output "Distribution Point is $($DP.DesSiteCode)"
        Write-Output "  UnlimitedRateForAll is currently $($DP.UnlimitedRateForAll)"
        If ($ApplyChanges) {
	        if($enable) {
                Write-Output "  Enabling Distribution Point Rate Limits"
    	        $dp.UnlimitedRateForAll = 0 
    	        $dp.RateLimitingSchedule = $RateLimitingSchedule 
	        } else {
                Write-Output "  Disabling Distribution Point Rate Limits"
		        $dp.UnlimitedRateForAll = 1
	        }
            try {
                $dp.Put() | Out-Null
                Write-Output "  Success"
            } catch {
                Write-Warning "  Failed"
            }
            Write-Output "  UnlimitedRateForAll is now $($DP.UnlimitedRateForAll)"
        } else {
            Write-Output "  Test mode... No changes made"
        }
    } else {
        Write-Error "  Failed to get Distribution Point"
    }
}
