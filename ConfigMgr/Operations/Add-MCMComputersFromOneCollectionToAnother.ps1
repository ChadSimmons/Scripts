# Add-MCMComputersFromOneCollectionToAnother.ps1
#.EXAMPLE
#
#   Add computers to GroupA deployment collections
#   $DelaySeconds = $(60*60*24); Do { scripts:\Add-MCMComputersFromOneCollectionToAnother.ps1 -GroupA; Write-Host "Rerunning at $($(Get-Date).AddSeconds($DelaySeconds))"; Start-Sleep -Seconds $DelaySeconds; } Until ( 1 -ne 1 )
#

[CmdletBinding()]
Param (
	[switch]$GroupA,
	[switch]$GroupB
)

$SiteCode = "LAB" # Site code
$ProviderMachineName = "ConfigMgr.contoso.com" # SMS Provider machine name
$initParams = @{}
if ($null -eq (Get-Module ConfigurationManager)) {
    Import-Module "$($ENV:SMS_ADMIN_UI_PATH)\..\ConfigurationManager.psd1" @initParams
}
if ($null -eq (Get-PSDrive -Name $SiteCode -PSProvider CMSite -ErrorAction SilentlyContinue)) {
    New-PSDrive -Name $SiteCode -PSProvider CMSite -Root $ProviderMachineName @initParams
}

Function Add-MCMCollectionMember ($SourceCollectionName, $DestinationCollectionName, $Max) {
    $iCount = 0; $Activity = "Adding Computers to ConfigMgr Collection [$SourceCollectionName]"
    Write-Progress -Activity $Activity -Status "Getting members from SOURCE Collection [$SourceCollectionName]"
    Push-Location -Path "$($SiteCode):\"

    $SelectObject = @('Name', 'CNIsOnline', 'CurrentLogonUser', 'LastLogonUser', 'PrimaryUser', 'LastActiveTime')
    $global:SourceMembersAll = @(Get-CMCollectionMember -CollectionName $SourceCollectionName | Sort-Object LastActiveTime -Descending | Select-Object $SelectObject) <# |`
        Sort-Object -Property `
        @{E = 'CNIsOnline'; Descending = $true}, `
        @{E = 'CurrentLogonUser'; Descending = $false}, `
        @{E = 'LastLogonUser'; Descending = $false}, `
        @{E = 'PrimaryUser'; Descending = $false}, `
        @{E = 'LastActiveTime'; Descending = $false} `
    #>
    $SourceMembers  = @()
    #Sort by CNIsOnline, CurrentLogonUser, PrimaryUser, LastLogonUser, LastActiveTime

    $SourceMembers += @($SourceMembersAll | Where-Object { $_.CNIsOnline -eq $true -and $null -eq $_.CurrentLogonUser -and $null -eq $_.PrimaryUser -and $null -eq $_.LastLogonUser })
    #next group is Offline with no primary user
    $SourceMembers += @($SourceMembersAll | Where-Object { $_.CNIsOnline -eq $false -and $null -eq $_.PrimaryUser })
    #last group is Offline with a primary user
    $SourceMembers += @($SourceMembersAll | Where-Object { $_.CNIsOnline -eq $false -and $null -ne $_.PrimaryUser })
    # get anything left
    $SourceMembers += @($SourceMembersAll | Where-Object { $_.Name -notin $SourceMembers.name })

    #$SourceMembersAll.count
    #$SourceMembers.count
    #$SourceMembers | Out-GridView -Title 'source members priority order'
    $SourceMembers = ($SourceMembers).Name

    Write-Progress -Activity $Activity -Status "Getting members from DESTINATION Collection [$DestinationCollectionName]"
    $DestinationMembers = @(Get-CMCollectionMember -CollectionName $DestinationCollectionName | Select-Object Name).Name

   	If ($DestinationMembers.count -eq 0) { $ComputersToAdd = $SourceMembers | Select-Object -First $Max
	} Else {
        $ComputersToAdd = @(Compare-Object -ReferenceObject $SourceMembers -DifferenceObject $DestinationMembers | Where-Object { $_.SideIndicator -eq '<=' } | Select-Object InputObject).InputObject | Select-Object -First $Max
    }
    $iCountTotal = $ComputersToAdd.Count

    Write-Progress -Activity $Activity -Status "[$iCount of $iCountTotal] $ComputerName" -CurrentOperation 'Getting collection object'
    $CMCollection = Get-CMCollection -CollectionType Device -Name $DestinationCollectionName
    ForEach ($ComputerName in $ComputersToAdd) {
        $iCount++
        Write-Progress -Activity $Activity -Status "[$iCount of $iCountTotal] $ComputerName" -PercentComplete ($iCount / $iCountTotal * 100)
        Write-Progress -Activity $Activity -Status "[$iCount of $iCountTotal] $ComputerName" -PercentComplete ($iCount / $iCountTotal * 100) -CurrentOperation 'Adding computer object'
        $CMComputer = Get-CMDevice -Fast -Name $ComputerName
        Add-CMDeviceCollectionDirectMembershipRule -InputObject $CMCollection -Resource $CMComputer
        Remove-Variable -Name CMComputer
    }
    Write-Progress -Activity $Activity -Status "Done" -Completed
    Pop-Location
}

$StartTime = Get-Date
Write-Output "Started at $(Get-Date -Date $StartTime)"

If ($GroupA) {
	Add-MCMCollectionMember -Max 10 -SourceCollectionName 'App1 targets' -DestinationCollectionName 'App1 rollout'
	Add-MCMCollectionMember -Max 50 -SourceCollectionName 'App2 targets' -DestinationCollectionName 'App2 rollout'
}
If ($GroupB) {
	Add-MCMCollectionMember -Max 10 -SourceCollectionName 'App3 targets' -DestinationCollectionName 'App3 rollout'
	Add-MCMCollectionMember -Max 50 -SourceCollectionName 'App4 targets' -DestinationCollectionName 'App4 rollout'
}
Write-Output "Completed in $("{0:g}" -f $(New-TimeSpan -Start $StartTime -End $(Get-Date))) at $(Get-Date)"