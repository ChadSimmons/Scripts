$SiteCode = "LAB"
$ProviderMachineName = "CMPrimary.contoso.com" # SMS Provider machine name
$DistributionPointGroupName = 'Data Center DPs'
$SourceDPname = 'SourceDP.contoso.com'
$TargetDPname = 'NewDP.contoso.com'


# Import the ConfigurationManager.psd1 module
if ($null -eq (Get-Module ConfigurationManager)) { Import-Module "$($ENV:SMS_ADMIN_UI_PATH)\..\ConfigurationManager.psd1" }

# Connect to the site's drive if it is not already present
if ($null -eq (Get-PSDrive -Name $SiteCode -PSProvider CMSite -ErrorAction SilentlyContinue)) { New-PSDrive -Name $SiteCode -PSProvider CMSite -Root $ProviderMachineName }

# Set the current location to be the site code.
Push-Location "$($SiteCode):\"


$DeploymentPackages = Get-CMDeploymentPackage -DistributionPointName $SourceDPname
#$DeploymentPackages | Select ObjectTypeID, PackageID, Name | Sort-Object ObjectTypeID, PackageID, Name
#$DeploymentPackages.Count

$DeploymentPackagesTarget = Get-CMDeploymentPackage -DistributionPointName $TargetDPname
#$DeploymentPackagesTarget | Select ObjectTypeID, PackageID, Name | Sort-Object ObjectTypeID, PackageID, Name
#$DeploymentPackagesTarget.Count

$MissingPackages = $DeploymentPackages | Where-Object { $_.PackageID -notin $DeploymentPackagesTarget.PackageID }
$MissingPackages | Select-Object ObjectTypeID, PackageID, Name | Sort-Object ObjectTypeID, PackageID, Name
$MissingPackages.Count
#$MissingPackages = $MissingPackages | Where { $_.PackageID -eq 'FC2001B2' } | Select *

ForEach ($DeploymentPackage in $MissingPackages) {
    $CMContentDistributionParams = $null
    Switch ($DeploymentPackage.ObjectTypeID) {
            2  { $CMContentDistributionParams = @{PackageID = $($DeploymentPackage.PackageID)} }
            14 { $CMContentDistributionParams = @{OperatingSystemInstallerId = $($DeploymentPackage.PackageID)} }
            18 { $CMContentDistributionParams = @{OperatingSystemImageId = $($DeploymentPackage.PackageID)} }
            19 { $CMContentDistributionParams = @{BootImageId = $($DeploymentPackage.PackageID)} }
            23 { $CMContentDistributionParams = @{DriverPackageID = $($DeploymentPackage.PackageID)} }
            24 { $CMContentDistributionParams = @{DeploymentPackageID = $($DeploymentPackage.PackageID)} }
            31 { $CMContentDistributionParams = @{ApplicationName = $($DeploymentPackage.Name)} }
        }
    If ($null -ne $CMContentDistributionParams) {
        Write-Output "Adding PackageID [$($DeploymentPackage.PackageID)] to Distribution Point Group [$DistributionPointGroupName]"
        Start-CMContentDistribution -DistributionPointGroupName $DistributionPointGroupName @CMContentDistributionParams
    }
}

Pop-Location