#.Synopsis
#   Set-MECMDistributionPoint_DistributeOnDemand.ps1
#   Enable/Disable ConfigMgr Distribution Point role DistributeOnDemand feature
#.LINK
#	SCCM Check "Enable for on-demand distribution" In "Distribution Point Properties" DistributeOnDemand https://franckrichard.blogspot.com/2018/05/sccm-check-enable-for-on-demand.html
[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact="Low")]
param (
	[parameter(Mandatory=$true)][string]$SiteCode = 'LAB',
	[parameter()][string[]]$DistributionPoint,
	[parameter(Mandatory=$true)][ValidateSet('Enable','Disable')][string]$Option
)

If ($Option -eq 'Enable') { $DistributeOnDemand = 1 }
If ($Option -eq 'Disable') { $DistributeOnDemand = 0 }

Push-Location -Path "$SiteCode`:"
If ($DistributionPoint.count -eq 0) {
	$DistributionPoint = @((Get-CMDistributionPoint -SiteCode $SiteCode).NALPath.split('\')[2])
}
$Count = 0
ForEach ($DPServer in $DistributionPoint) {
    $Count++
	$ProgressActivity = "ConfigMgr Distribution Point Distribute On Demand feature: Processing server $Count of $($DistributionPoint.count)"
    Write-Progress -Activity $ProgressActivity -Status "$DPServer... getting DP object"
	$DP = Get-CMDistributionPoint -SiteCode $SiteCode -SiteSystemServerName $DPServer
	$props = $DP.EmbeddedProperties
	if ($DP.EmbeddedProperties.ContainsKey('DistributeOnDemand') ) {
		$props['DistributeOnDemand'].Value = $DistributeOnDemand
	} else {
		$props['DistributeOnDemand'] = New-CMEmbeddedProperty -PropertyName 'DistributeOnDemand' -Value $DistributeOnDemand
	}
	$DP.EmbeddedProperties = $props
	If ($WhatIfPreference -eq $false) {
    Write-Progress -Activity $ProgressActivity -Status "$DPServer... setting DP object"
        try {
		    $DP.put()
            Write-Output "Set DP $DPServer DistributeOnDemand to $Option"
        } catch {
            Write-Error "Failed setting DP $DPServer DistributeOnDemand to $($DistributeOnDemand)"
        }
	} Else {
        Write-Output "Would have set DP $DPServer DistributeOnDemand to $Option"
    }
}
Pop-Location
Write-Progress -Activity $ProgressActivity -Status "Done"; Start-Sleep -Seconds 1
Write-Progress -Activity $ProgressActivity -Status "Done" -Completed
