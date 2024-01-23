$SMSProvider = "localhost"
$CollectionName = "Deploy Windows 7 SP1"
$LogFile = 'D:\Logs\OSD\Clear-CollectionMembership.log'

Function Get-SiteCode
{
    $wqlQuery = “SELECT * FROM SMS_ProviderLocation”
    $a = Get-WmiObject -Query $wqlQuery -Namespace “root\sms” -ComputerName $SMSProvider
    $a | ForEach-Object {
        if($_.ProviderForLocalSite)
            {
                $script:SiteCode = $_.SiteCode
            }
    }
}

Get-SiteCode

#Import the CM12 Powershell cmdlets
if (-not (Test-Path -Path $SiteCode))
    {
        Write-Verbose "$(Get-Date):   CM12 module has not been imported yet, will import it now."
        Import-Module ($env:SMS_ADMIN_UI_PATH.Substring(0,$env:SMS_ADMIN_UI_PATH.Length – 5) + '\ConfigurationManager.psd1') | Out-Null
    }
#CM12 cmdlets need to be run from the CM12 drive
Set-Location "$($SiteCode):" | Out-Null
if (-not (Get-PSDrive -Name $SiteCode))
    {
        Write-Error "There was a problem loading the Configuration Manager powershell module and accessing the site's PSDrive."
        exit 1
    }

$Collection = Get-CMDeviceCollection -Name $CollectionName

#Get-WmiObject -Class SMS_FullCollectionMembership -Namespace root\SMS\Site_$SiteCode -Filter "CollectionID = '$($Collection.CollectionID)' AND IsClient = '1'" | Remove-CMDeviceCollectionDirectMembershipRule -CollectionId $Collection.CollectionID –Force
#Get-WmiObject -Class SMS_FullCollectionMembership -Namespace root\SMS\Site_$SiteCode -Filter "CollectionID = '$($Collection.CollectionID)'" | Select ResourceID | Remove-CMDeviceCollectionDirectMembershipRule -CollectionId $Collection.CollectionID –Force
$members = Get-WmiObject -class SMS_FullCollectionMembership -Namespace root\SMS\Site_$SiteCode -Filter "CollectionID = '$($Collection.CollectionID)' AND IsClient = '1'"
foreach ($member in $members)
	{
		Add-Content -Path $LogFile -Value "$(Get-Date -Format "yyyy-MM-dd HH:mm:ss");$($member.Name) with ResourceID $($member.ResourceID) is being removed from Collection '$CollectionName ($($member.CollectionID))'" 
		Remove-CMDeviceCollectionDirectMembershipRule -CollectionID $member.CollectionID -ResourceID $member.ResourceID -force
	}
