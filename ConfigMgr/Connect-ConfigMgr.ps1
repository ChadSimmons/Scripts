Function Connect-ConfigMgr {
    #.Synopsis
    #   Load Configuration Manager PowerShell Module
    #.Description
    #   if SiteCode is not specified, detect it
    #   if SiteServer is not specified, use the computer from PSDrive if it exists, otherwise use the current computer
    #.Link
    #   http://blogs.technet.com/b/configmgrdogs/archive/2015/01/05/powershell-ise-add-on-to-connect-to-configmgr-connect-configmgr.aspx
	Param (
		[Parameter(Mandatory=$false)][ValidateLength(3,3)][string]$SiteCode,
		[Parameter(Mandatory=$false)][ValidateLength(1,255)][string]$SiteServer
	)
    If ($null -eq $Env:SMS_ADMIN_UI_PATH) {
        #import the module if it exists
        If ($null -eq (Get-Module ConfigurationManager)) {
            Write-Verbose 'Importing ConfigMgr PowerShell Module...'
            $TempVerbosePreference = $VerbosePreference
            $VerbosePreference = 'SilentlyContinue'
            try {
                ##Alternate method by https://kelleymd.wordpress.com/2015/03/26/powershell-module-reference-and-auto-load
                #<!remove the underscores!>R_e_q_u_i_r_e_s –Modules "$($ENV:SMS_ADMIN_UI_PATH)\..\ConfigurationManager.psd1"
                #get-help Get-CMSite
                Import-Module "$($ENV:SMS_ADMIN_UI_PATH)\..\ConfigurationManager.psd1"
            } catch {
                Write-Error 'Failed Importing ConfigMgr PowerShell Module.'
                Throw $_
            }
            $VerbosePreference = $TempVerbosePreference
            Remove-Variable TempVerbosePreference
        } else {
            Write-Verbose "The ConfigMgr PowerShell Module is already loaded."
        }
        # If SiteCode was not specified detect it
        If ([string]::IsNullOrEmpty($SiteCode)) {
            try {
                $SiteCode  = (Get-PSDrive -PSProvider CMSite -ErrorAction Stop).Name
            } catch {
                Throw $_
            }
        }
        # Connect to the site's drive if it is not already present
        if ($null -eq (Get-PSDrive -Name $SiteCode -PSProvider CMSite -ErrorAction SilentlyContinue)) {
            Write-Verbose -Message "Creating ConfigMgr Site Drive $($SiteCode):\ on server $SiteServer"
            # If SiteCode was not specified use the current computer
            If ([string]::IsNullOrEmpty($SiteServer)) {
                $SiteServer = $env:ComputerName
            }
            try {
                New-PSDrive -Name $SiteCode -PSProvider CMSite -Root $SiteServer -Scope Global #-Persist
            } catch {
                Throw $_
            }
        }
        #change location to the ConfigMgr Site
        try {
            Push-Location "$($SiteCode):\"
            Pop-Location
        } catch {
            Write-Error "Error connecting to the ConfigMgr site"
            Throw $_
        }
    } else {
        Throw "The ConfigMgr PowerShell Module does not exist!  Install the ConfigMgr Admin Console first."
    }
}; Set-Alias -Name 'Connect-CMSite' -Value 'Connect-ConfigMgr' -Description 'Load the ConfigMgr PowerShell Module and connect to a ConfigMgr site'