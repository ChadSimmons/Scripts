function Get-DPRateLimits
{
<#
.SYNOPSIS
Query for Distribution Points that have RateLimits set or not.
.DESCRIPTION
Query for Distribution Points that have RateLimits set or not. This is set on the Rate Limits Tab of the Distribution point Properties
in the Console. The equivalent action in the gui to that if the "Unlimited when sending to this destination" radio button is NOT set, then the Rate limits are enabled. If it is set then Rate Limits are not enabled.
.PARAMETER -SiteServer
Server name of the Primary Site. Required
.PARAMETER -SiteCode
Site Code of the Primary Site used in the -SiteServer parameter. Required
.PARAMETER -Enable
Used to specify  to query for systems with Rate limits enabled or disabled. Only accepts $true or $false
This is an optional parameter. By default it will be $true.
.EXAMPLE
Get-DPRateLimits -SiteServer CMPrimary -SiteCode LAB -Enable $true
Query for Distribution Points with Rate Limits enabled
.EXAMPLE
Get-DPRateLimits -SiteServer CMPrimary -SiteCode LAB -Enable $false
Query for Distribution Points without Rate Limits enabled
.Notes
	Author: Jon Warnken jon.warnken@gmail.com
	Revisions:
		1.0 06/23/2014 - Original creation.

#>
[CmdletBinding()]

param (
[Parameter(Mandatory=$true,Position=1)]
[string]$SiteServer,
[Parameter(Mandatory=$true,Position=2)]
[string]$SiteCode,
[Parameter(Mandatory=$false,Position=3)]
[Boolean]$Enable=$True
)

	if($Enable){
		$dp = Get-WmiObject -ComputerName $SiteServer -namespace "root\sms\site_$SiteCode" -query "select * from SMS_SCI_address where UnlimitedRateForAll = 'False'"
	}else{
		$dp = Get-WmiObject -ComputerName $SiteServer -namespace "root\sms\site_$SiteCode" -query "select * from SMS_SCI_address where UnlimitedRateForAll = 'True'"
	}
    return $dp
}