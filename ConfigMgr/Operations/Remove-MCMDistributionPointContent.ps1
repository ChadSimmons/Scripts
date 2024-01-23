
function Remove-SCCMDPContent
{
<#
.Synopsis
    Function to Remove Packages from the DP
.DESCRIPTION
    THis Function will connect to the SCCM Server SMS namespace and then remove the Package IDs
    passed to the Function from the specified DP name.
.EXAMPLE
    PS> Remove-SCCMDPContent -PackageID DEX123AB,DEX145CD -DPname DexDP -Computername DexSCCMServer  

    This will remove the Packages with Package IDs [ DEX123AB,DEX145CD] from the Distribution Point "DexDP".
.INPUTS
    System.String[]
.OUTPUTS
    System.Management.Automation.PSCustomObject
.NOTES
    Author - DexterPOSH (Deepak Singh Dhami)

#>

    [CmdletBinding()]
    [OutputType([PSObject])]
    Param
    (
        # Specify the Package IDs which need to be removed from the DP
        [Parameter(Mandatory,
                   ValueFromPipelineByPropertyName,
                   Position=0)]
        [string[]]$PackageID,

        # Pass the DP name where cleanup is to be done
        [Parameter(Mandatory=$true)]
        [String]$DPName,

        #Supply the SCCM Site Server hosting SMS Namespace Provider
        [Parameter()]
        [Alias("SCCMServer")]
        [String]$ComputerName
    )

    Begin
    {
        Write-Verbose -Message "[BEGIN]"
        try
        {
           
            $sccmProvider = Get-WmiObject -query "select * from SMS_ProviderLocation where ProviderForLocalSite = true" -Namespace "root\sms" -computername $ComputerName -errorAction Stop
            # Split up the namespace path
            $Splits = $sccmProvider.NamespacePath -split "\\", 4
            Write-Verbose "Provider is located on $($sccmProvider.Machine) in namespace $($splits[3])"
 
            # Create a new hash to be passed on later
            $hash= @{"ComputerName"=$ComputerName;"NameSpace"=$Splits[3];"Class"="SMS_DistributionPoint";"ErrorAction"="Stop"}
            
            #add the filter to get the packages there in the DP only
            $hash.Add("Filter","ServerNALPath LIKE '%$DPname%'")

            
        }
        catch
        {
            Write-Warning "Something went wrong while getting the SMS ProviderLocation"
            throw $_.Exception
        }
    }
    Process
    {
        
            
            Write-Verbose -Message "[PROCESS] Working to remove packages from DP --> $DPName  "
            
            #get all the packages in the Distribution Point
            $PackagesINDP = Get-WmiObject @hash
            
            #Filter the packages based on the PackageID
            $RemovePackages = $PackagesINDP | where {$PackageID -contains $_.packageid   }
            
            
            $Removepackages | ForEach-Object -Process { 
                try 
                {
                    Remove-WmiObject  -InputObject $_  -ErrorAction Stop -ErrorVariable WMIRemoveError 
                    Write-Verbose -Message "Removed $($_.PackageID) from $DPname"
                    [pscustomobject]@{"DP"=$DPname;"PackageId"=$($_.PackageID);"Action"="Removed"}
                                                                 
                }
                catch
                {
                    Write-Warning "[PROCESS] Something went wrong while removing the Package  from $DPname"
                    throw $_.exception
                }
            }#End Foreach-Object
            
        }#End Process
    End
    {
        Write-Verbose "[END] Ending the Function"
    }
}