NOT COMPELTE


#Migrate Packages from Source ConfigMgr environment to new ConfigMgr environment
#Install ConfigMgr Admin Console on Source DP
#Create pre-staged content files on Source DP (RDP into Source DP to do this... or run the script remotely)
#Install new DP but do NOT assign it to a DP group
#Enable the Target DP for Pre-Staged Content
#Assign new DP to appropriate DP groups
#Copy/Move pre-staged PKGX files to Target DP
#Run ExtractContent.exe for all PKGX files on Target DP
#Wait awhile for the Distribution Manager and Package Transfer Manager to update the Package status on the DP
#Disable the Target DP for Pre-Staged Content
#Delete the PKGX files on the Target DP (and Source DP if they still exist)


# Ken Smith
# Microsoft Premier Field Engineer (PFE)
# http://twitter.com/pfeken
# http://blogs.technet.com/b/kensmith/
#.LINK
#   https://blogs.technet.microsoft.com/kensmith/2013/08/01/migrating-the-content-library-between-distribution-points-in-sccm-2012-sp1/
#   https://gallery.technet.microsoft.com/CloneDP-for-SCCM-2012-SP1-825ce5b1
# 
# 07/28/2013
# Rev 1.1
#
# This script demonstrates how to clone the contents of one distribution point onto another.  This is useful if you need to 
# reload a DP, or if you are migrating to new hardware and do not want to copy packages over the WAN.
#
# Usage: CloneDP <mode> <mode options>
# 
# Modes
# =====
#     -PreStage - This mode will create prestage files for all of the content on the source DP
#     -Finalize - This mode will distribute content to the destination DP - any prestaged content will use the local copy
#        
# Mode Options
# ============
#     -TargetDP (Required) - The destination DP for the clone operation
#     -SourceDP (Required) - The source DP for the clone operation
#     -ContentShare (Optional) - This option is required for the prestage mode, prestage files will be moved here for import
#
# This Sample Code is provided for the purpose of illustration only and is not intended to be used in a production environment.  
# THIS SAMPLE CODE AND ANY RELATED INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED OR IMPLIED, 
# INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR PURPOSE.  
# We grant You a nonexclusive, royalty-free right to use and modify the Sample Code and to reproduce and distribute the object
# code form of the Sample Code, provided that You agree: (i) to not use Our name, logo, or trademarks to market Your software 
# product in which the Sample Code is embedded; (ii) to include a valid copyright notice on Your software product in which the 
# Sample Code is embedded; and (iii) to indemnify, hold harmless, and defend Us and Our suppliers from and against any claims 
# or lawsuits, including attorneys’ fees, that arise or result from the use or distribution of the Sample Code.

Param(
  [parameter(ParameterSetName="Source")][switch]$Source,
  [parameter(ParameterSetName="finalize")][switch]$Finalize,
  [parameter(Mandatory=$True)][string]$TargetDP,
  [parameter(Mandatory=$True)][string]$SourceDP,
  [string]$ContentShare
)

-Source
-SourceDP = "$env:ComputerName"
-ExportPath = "$env:ComputerName\Admin$\Temp"

-Target
-TargetDP = "$env:ComputerName"
-SourcePath
-TargetPath
-LeaveSource


Function Export-Content ($DeploymentPackages, $DisbributionPoint, $Path) {
    Write-Verbose "Gathering content from $($SourceDP)"
    Push-Location -Path "$(get-psdrive –PSProvider CMSite):\"
    $i=0
    ForEach ($DeploymentPackage in $DeploymentPackages) {
        $i++
        Write-Progress -Activity "Gathering content from $($SourceDP)" -Status "[$i of $($DeploymentPackages.Count)] Content ???" -PercentComplete ($i/$($DeploymentPackages.Count)*100)
        Switch ($DeploymentPackage.ObjectTypeID) { #Set command arguments depending on the content's type ID
            2  { $command += "-PackageID $($DeploymentPackage.PackageID) " } #Package
            14 { $command += "-OperatingSystemInstallerId $($DeploymentPackage.PackageID) "} #Operating System Installer Package
            18 { $command += "-OperatingSystemImageId $($DeploymentPackage.PackageID) "} #Operating System Image Package
            19 { $command += "-BootImageId "} #OSD Boot Image Package
            23 { $command += "-DriverPackageID $($DeploymentPackage.PackageID) "} #Driver Package
            24 { $command += "-DeploymentPackageID $($DeploymentPackage.PackageID) "} #Software Update Package
            31 { $command += "-ApplicationName '$($DeploymentPackage.Name)' "} #Application Package
        }
        If (($DeploymentPackage.ObjectTypeID -eq 20) -or ($DeploymentPackage.ObjectTypeID -eq 21)) {
            Write-Warning "Skipping $($DeploymentPackage.PackageID) due to unsupported content type"  #Device Settings and Task Sequence packages cannot be prestaged
        } Else {
            Write-Verbose "Creating prestage content file $Path\$($DeploymentPackage.PackageID).pkgx"
            Invoke-Expression "Publish-CMPrestageContent $command -FileName '$Path\$($DeploymentPackage.PackageID).pkgx' -DistributionPointName $($SourceDP)"
        }
    }
    Pop-Location
}

Function Move-Content ($SourcePath, $TargetPath, [switch]$LeaveSource) {
    Write-Verbose "Moving content from $SourcePath to $TargetPath"
    If ($LeaveSource) { 
        Write-Verbose "Content on $SourcePath will NOT be deleted"
    }
    $Files = Get-ChildItem -Path $SourcePath -Filter '*.pkgx'
    $i=0
    ForEach ($File in $Files) {
        $i++
        Write-Progress -Activity "Moving content from $($SourceDP)" -Status "[$i of $($Files.Count)] $($File.FullName)" -PercentComplete ($i/$($Files.Count)*100)
        Copy-Item -Path $File -Destination $TargetPath -Force -ErrorVariable CopyStatus
        If ($LeaveSource) {
        } Else {
            If ($CopyStatus) {
            } Else {
                Remove-Item -Path $File
            }
        }
}

Function Import-Content ($SourcePath, $DistributeContent) {
    #TODO: ExtractContent
}

Function Distribute-Content ($ContentID) {
    Write-Host "Assigning $($DeploymentPackage.PackageID) to $($TargetDP)"
    #We are in finalize mode; assign content distribution to the DP
    Start-CMContentDistribution -DistributionPointName $($TargetDP)  
}

ForEach ($DeploymentPackage in $DeploymentPackages) {
}


Import-Module -Name ($Env:SMS_ADMIN_UI_PATH.Substring(0,$Env:SMS_ADMIN_UI_PATH.Length-5) + '\ConfigurationManager.psd1')
Push-Location -Path "$(get-psdrive –PSProvider CMSite):\"

$DeploymentPackages = Get-CMDeploymentPackage -DistributionPointName $SourceDP

Export-Content -DeploymentPackages $DeploymentPackages -DisbributionPoint $SourceDP -Path "\\$SourceDP\admin$\Temp"
Move-Content -SourcePath "\\$SourceDP\admin$\Temp" -TargetPath "\\$SourceDP\admin$\Temp" -LeaveSource
