#--------------------------------------------------------------------------------- 
#The sample scripts are not supported under any Microsoft standard support 
#program or service. The sample scripts are provided AS IS without warranty  
#of any kind. Microsoft further disclaims all implied warranties including,  
#without limitation, any implied warranties of merchantability or of fitness for 
#a particular purpose. The entire risk arising out of the use or performance of  
#the sample scripts and documentation remains with you. In no event shall 
#Microsoft, its authors, or anyone else involved in the creation, production, or 
#delivery of the scripts be liable for any damages whatsoever (including, 
#without limitation, damages for loss of business profits, business interruption, 
#loss of business information, or other pecuniary loss) arising out of the use 
#of or inability to use the sample scripts or documentation, even if Microsoft 
#has been advised of the possibility of such damages 
#--------------------------------------------------------------------------------- 

#requires -Version 2.0

<#
 	.SYNOPSIS
        This script can be list all of shared folder permission or ntfs permission.
		
    .DESCRIPTION
        This script can be list all of shared folder permission or ntfs permission.
		
	.PARAMETER  <SharedFolderNTFSPermission>
		Lists all of ntfs permission of SharedFolder.
		
	.PARAMETER	<ComputerName <string[]>
		Specifies the computers on which the command runs. The default is the local computer. 
		
	.PARAMETER  <Credential>
		Specifies a user account that has permission to perform this action. 
		
    .EXAMPLE
        C:\PS> Get-OSCFolderPermission -NTFSPermission
		
		This example lists all of ntfs permission of SharedFolder on the local computer.
		
    .EXAMPLE
		C:\PS> $cre = Get-Credential
        C:\PS> .\Get-ShareAndFolderPermissions.ps1 -ComputerName "APP" -Credential $cre
		
		This example lists all of share permission of SharedFolder on the APP remote computer.
		
	.EXAMPLE
        C:\PS> .\Get-ShareAndFolderPermissions.ps1 | Export-Csv -Path "D:\Share-SharePermission.csv" -NoTypeInformation
        C:\PS> .\Get-ShareAndFolderPermissions.ps1 -NTFSPermission | Export-Csv -Path "D:\Share-FolderPermission.csv" -NoTypeInformation
	
		This example will export report to csv file. If you attach the <NoTypeInformation> parameter with command, it will omits the type information 
		from the CSV file. By default, the first line of the CSV file contains "#TYPE " followed by the fully-qualified name of the object type.
	.LINK
		http://gallery.technet.microsoft.com/scriptcenter/Lists-all-the-shared-5ebb395a
#>

Param
(
	[Parameter(Mandatory=$false)]
	[Alias('Computer')][String[]]$ComputerName=$Env:COMPUTERNAME,

	[Parameter(Mandatory=$false)]
	[Alias('NTFS')][Switch]$NTFSPermission,
	
	[Parameter(Mandatory=$false)]
	[Alias('Cred')][System.Management.Automation.PsCredential]$Credential
)

$RecordErrorAction = $ErrorActionPreference
#change the error action temporarily
$ErrorActionPreference = "SilentlyContinue"

Function GetSharedFolderPermission($ComputerName)
{
	#test server connectivity
	$PingResult = Test-Connection -ComputerName $ComputerName -Count 1 -Quiet
	if($PingResult)
	{
		#check the credential whether trigger
		if($Credential)
		{
			$SharedFolderSecs = Get-WmiObject -Class Win32_LogicalShareSecuritySetting `
			-ComputerName $ComputerName -Credential $Credential -ErrorAction SilentlyContinue
		}
		else
		{
			$SharedFolderSecs = Get-WmiObject -Class Win32_LogicalShareSecuritySetting `
			-ComputerName $ComputerName -ErrorAction SilentlyContinue
		}
		
		foreach ($SharedFolderSec in $SharedFolderSecs) 
		{ 
		    $Objs = @() #define the empty array
			
	        $SecDescriptor = $SharedFolderSec.GetSecurityDescriptor()
	        foreach($DACL in $SecDescriptor.Descriptor.DACL)
			{  
				$DACLDomain = $DACL.Trustee.Domain
				$DACLName = $DACL.Trustee.Name
				if($DACLDomain -ne $null)
				{
	           		$UserName = "$DACLDomain\$DACLName"
				}
				else
				{
					$UserName = "$DACLName"
				}
				
				#customize the property
				$Properties = @{'ComputerName' = $ComputerName
								'ConnectionStatus' = "Success"
								'SharedFolderName' = $SharedFolderSec.Name
								'SecurityPrincipal' = $UserName
								'FileSystemRights' = [Security.AccessControl.FileSystemRights]`
								$($DACL.AccessMask -as [Security.AccessControl.FileSystemRights])
								'AccessControlType' = [Security.AccessControl.AceType]$DACL.AceType}
				$SharedACLs = New-Object -TypeName PSObject -Property $Properties
				$Objs += $SharedACLs

	        }
			$Objs|Select-Object ComputerName,ConnectionStatus,SharedFolderName,SecurityPrincipal, `
			FileSystemRights,AccessControlType
	    }  
	}
	else
	{
		$Properties = @{'ComputerName' = $ComputerName
						'ConnectionStatus' = "Fail"
						'SharedFolderName' = "Not Available"
						'SecurityPrincipal' = "Not Available"
						'FileSystemRights' = "Not Available"
						'AccessControlType' = "Not Available"}
		$SharedACLs = New-Object -TypeName PSObject -Property $Properties
		$Objs += $SharedACLs
		$Objs|Select-Object ComputerName,ConnectionStatus,SharedFolderName,SecurityPrincipal, `
		FileSystemRights,AccessControlType
	}
}

Function GetSharedFolderNTFSPermission($ComputerName)
{
	#test server connectivity
	$PingResult = Test-Connection -ComputerName $ComputerName -Count 1 -Quiet
	if($PingResult)
	{
		#check the credential whether trigger
		if($Credential)
		{
			$SharedFolders = Get-WmiObject -Class Win32_Share `
			-ComputerName $ComputerName -Credential $Credential -ErrorAction SilentlyContinue
		}
		else
		{
			$SharedFolders = Get-WmiObject -Class Win32_Share `
			-ComputerName $ComputerName -ErrorAction SilentlyContinue
		}

		foreach($SharedFolder in $SharedFolders)
		{
			$Objs = @()
			
			$SharedFolderPath = [regex]::Escape($SharedFolder.Path)
			if($Credential)
			{	
				$SharedNTFSSecs = Get-WmiObject -Class Win32_LogicalFileSecuritySetting `
				-Filter "Path='$SharedFolderPath'" -ComputerName $ComputerName  -Credential $Credential
			}
			else
			{
				$SharedNTFSSecs = Get-WmiObject -Class Win32_LogicalFileSecuritySetting `
				-Filter "Path='$SharedFolderPath'" -ComputerName $ComputerName
			}
			
			$SecDescriptor = $SharedNTFSSecs.GetSecurityDescriptor()
			foreach($DACL in $SecDescriptor.Descriptor.DACL)
			{  
				$DACLDomain = $DACL.Trustee.Domain
				$DACLName = $DACL.Trustee.Name
				if($DACLDomain -ne $null)
				{
	           		$UserName = "$DACLDomain\$DACLName"
				}
				else
				{
					$UserName = "$DACLName"
				}
				
				#customize the property
				$Properties = @{'ComputerName' = $ComputerName
								'ConnectionStatus' = "Success"
								'SharedFolderName' = $SharedFolder.Name
								'SecurityPrincipal' = $UserName
								'FileSystemRights' = [Security.AccessControl.FileSystemRights]`
								$($DACL.AccessMask -as [Security.AccessControl.FileSystemRights])
								'AccessControlType' = [Security.AccessControl.AceType]$DACL.AceType
								'AccessControlFalgs' = [Security.AccessControl.AceFlags]$DACL.AceFlags}
								
				$SharedNTFSACL = New-Object -TypeName PSObject -Property $Properties
	            $Objs += $SharedNTFSACL
	        }
			$Objs |Select-Object ComputerName,ConnectionStatus,SharedFolderName,SecurityPrincipal,FileSystemRights, `
			AccessControlType,AccessControlFalgs -Unique
		}
	}
	else
	{
		$Properties = @{'ComputerName' = $ComputerName
						'ConnectionStatus' = "Fail"
						'SharedFolderName' = "Not Available"
						'SecurityPrincipal' = "Not Available"
						'FileSystemRights' = "Not Available"
						'AccessControlType' = "Not Available"
						'AccessControlFalgs' = "Not Available"}
					
		$SharedNTFSACL = New-Object -TypeName PSObject -Property $Properties
	    $Objs += $SharedNTFSACL
		$Objs |Select-Object ComputerName,ConnectionStatus,SharedFolderName,SecurityPrincipal,FileSystemRights, `
		AccessControlType,AccessControlFalgs -Unique
	}
} 

foreach($CN in $ComputerName)
{
	
	if($NTFSPermission)
	{
		GetSharedFolderNTFSPermission -ComputerName $CN
	}
	else
	{
		GetSharedFolderPermission -ComputerName $CN
	}
}
#restore the error action
$ErrorActionPreference = $RecordErrorAction