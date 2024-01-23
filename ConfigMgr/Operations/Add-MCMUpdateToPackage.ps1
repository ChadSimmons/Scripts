param (
[string]$DeploymentPackage,
[string]$SoftwareUpdateGroup,
[string]$SiteCode,
[string]$SiteServer
)

#Function to download updates from the specified URL to the specified path
function Get-Update {
    param (
    [string]$URL,
    [string]$Path
    )
    $File = Split-Path -Leaf $URL
    $FilePath = "$Path\$File"
    
    try {
        "Started downloading from [$URL]" 
        $WebClient = New-Object System.Net.WebClient 
        $WebClient.DownloadFile($URL, $FilePath) 
        "Finished downloading to [$FilePath]"
    }
    catch {
        "Failed to download from [$URL]"
        "Error: $_"
    }
}

#Function to add update content to a deployment package
function Add-UpdateContent {
    param (
        [string]$DeploymentPackage,
        [array]$UpdateContentIDs,
        [array]$UpdateContentSourcePaths
    )
    try {
        $PackageID = (Get-WmiObject -Namespace root/SMS/site_$($SiteCode) -ComputerName $SiteServer -Query "SELECT * FROM SMS_SoftwareUpdatesPackage WHERE Name='$DeploymentPackage'").PackageID
        Invoke-WmiMethod -Path "\\$($SiteServer)\root\sms\site_$($SiteCode):SMS_SoftwareUpdatesPackage.PackageID='$PackageID'" -Name AddUpdateContent -ArgumentList @($false,$UpdateContentIDs,$UpdateContentSourcePaths)
        "Added content to the deployment package."                
    }
    catch {
        "Failed to add content to the deployment package."                
        "Error: $_"
    }
}

$TempDownloadPath = "C:\Temp" #Set temporary download location
New-Item -Path $TempDownloadPath -ItemType Directory #Create temporary download location

$UpdateContentIDs = @() #Create empty array for the update content IDs
$UpdateContentSourcePaths = @() #Create empty arrays for the update content source path
$UpdateGroupCIID = (Get-WmiObject -Namespace root/SMS/site_$($SiteCode) -ComputerName $SiteServer -Query "SELECT * FROM SMS_AuthorizationList WHERE LocalizedDisplayName='$SoftwareUpdateGroup'").CI_ID #Get the CI ID of the software update group
$Updates = Get-WmiObject -Namespace root/SMS/site_$($SiteCode) -ComputerName $SiteServer -Query "SELECT upd.* FROM SMS_SoftwareUpdate upd, SMS_CIRelation cr WHERE cr.FromCIID='$UpdateGroupCIID' AND cr.RelationType=1 AND upd.IsContentProvisioned=0 AND upd.CI_ID=cr.ToCIID" #Get the updates that are member of the software update group via the CI ID
foreach ($Update in $Updates) { #Foreach update find the content location and download the content
    $UpdateCIID = $Update.CI_ID
    $UpdateContent = Get-WmiObject -Namespace root/SMS/site_$($SiteCode) -ComputerName $SiteServer -Query "SELECT fil.* FROM SMS_CIToContent con, SMS_CIContentFiles fil WHERE con.CI_ID='$UpdateCIID' AND con.ContentID=fil.ContentID" #Get the content information of the software updates CI ID
    foreach ($Content in $UpdateContent) { #Foreach content of the update, download the content
        Get-Update $Content.SourceURL $TempDownloadPath #Download the content to the temporary download location
        $UpdateContentIDs += $Content.ContentID #Store the content ID
        $UpdateContentSourcePaths += $TempDownloadPath #Store the temporary download location
    }   
}

Add-UpdateContent $DeploymentPackage $UpdateContentIDs $UpdateContentSourcePaths #Add updates from the temporary location to the deployment package
Remove-Item $TempDownloadPath -Force -Recurse #Remove temporary download location