Function Update-MECMObjectSecurityScopes {
	#.Synopsis
	#	Add and Remove Security Scopes from an array of ConfigMgr objects
	#.Notes
	#   === To Do / Proposed Changes ===
	#	- TODO: add error handling
	param (
		[Parameter(Mandatory = $true)]$ObjectID,
		[Parameter(Mandatory = $true)][string]$ObjectType,
		[Parameter(Mandatory = $false)][string]$AddScopeName,
		[Parameter(Mandatory = $false)][string]$RemoveScopeName,
		[Parameter(Mandatory = $true)][string]$SiteCode
	)
	Begin {
		Connect-ConfigMgr
		Push-Location "$SiteCode`:\"
		$AddScope = Get-CMSecurityScope -Name $AddScopeName
		$RemoveScope = Get-CMSecurityScope -Name $RemoveScopeName
		Pop-Location
	}
	Process {
		ForEach ($ObjectIDInstance in $ObjectID) {
			Switch ($ObjectType) {
				'Application' {
					Push-Location "$SiteCode`:\"
					$CMObject = Get-CMApplication -Id $ObjectIDInstance
					Pop-Location
					Write-LogMessage -Message "Verifying Application CI_ID [$($CMObject.CI_ID)] named [$($CMObject.LocalizedDisplayName)]"
				}
				'Package' {
					Push-Location "$SiteCode`:\"
					$CMObject = Get-CMPackage -Id $ObjectIDInstance
					Pop-Location
					Write-LogMessage -Message "Verifying Package ID [$($CMObject.PackageID)] named [$($CMObject.Name)]"
				}
				'TaskSequence' {
					Push-Location "$SiteCode`:\"
					$CMObject = Get-CMApplication -Id $ObjectIDInstance
					Pop-Location
					Write-LogMessage -Message "Verifying TaskSequence ID [$($CMObject.PackageID)] named [$($CMObject.Name)]"
				}
			}
			Push-Location "$SiteCode`:\"
			$CMObjectScopes = Get-CMObjectSecurityScope -InputObject $CMObject
			Pop-Location
			Write-LogMessage -Message "[$ObjectType] Object ID [$ObjectIDInstance] has [$($CMObjectScopes.Count)] scopes assigned"
			If ($CMObjectScopes.CategoryID -notcontains $AddScope.CategoryID) {
				#Add the production Security Scope if it isn't already added
				Write-LogMessage -Message "Adding scope [$AddScopeName] to [$ObjectType] Object ID [$ObjectIDInstance]"
				Push-Location "$SiteCode`:\"
				Add-CMObjectSecurityScope -InputObject $CMObject -Scope $AddScope -Confirm:$false -Force
				Pop-Location
			}
			If ($CMObjectScopes.CategoryID -contains $RemoveScope.CategoryID) {
				#Remove the lab Security Scope if it is added
				Write-LogMessage -Message "Removing scope [$RemoveScopeName] from [$ObjectType] Object ID [$ObjectIDInstance]"
				Push-Location "$SiteCode`:\"
				Remove-CMObjectSecurityScope -InputObject $CMObject -Scope $RemoveScope -Confirm:$false -Force
				Pop-Location
			}
			#Set-CMObjectSecurityScope -InputObject $CMPackage -Action AddMembership -Name 'Stores-Production'
			#Set-CMObjectSecurityScope -InputObject $CMPackage -Action RemoveMembership -Name 'Stores-TCoE Lab'
			#Add-CMObjectSecurityScope -InputObject $CMPackage -Name 'Stores-Production'
			#Remove-CMObjectSecurityScope -InputObject $CMPackage -Name 'Stores-TCoE Lab'
		}
	}
	End {
	}
}