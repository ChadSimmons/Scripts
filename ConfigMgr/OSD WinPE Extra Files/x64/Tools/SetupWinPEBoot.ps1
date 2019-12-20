<#
.SYNOPSIS
	This will ensure that WinPE boot image won't get staged on to USB hardDisk,
	Otherwise a USB could be used for staging and the TS initialization would fail in WinPE. In that case machine wouldn't boot and 
	requires an alternate boot mechanism to restore previous boot configuration.

.DESCRIPTION
	1)  Checks if the TaskSequence data path(_SMSTSMDataPath) drive is encrypted(protected by bitlocker). If it isn't then, it would exit without doing anything.
		That is because, TS engine would always choose TS data drive to stage the boot image, if it isn't encrypted. It starts to look for
		other drives only when the TS data drive is encrypted.
	2) 	If TS data drive is encrypted, then it Checks if there are any mounted USB hardDisks. If there aren't any then, it would exit without doing anything.
		That is because, as long as local drive(non USB) is chosen for staging the boot image, TS initialization should go through in WinPE. It doesn't matter whether TS data drive is chosen for staging.
	3)	If any USB hardDisk is found, then it initiates download of boot image. The reason for downloading it ahead of time is, TaskSequence could be using USB to download
		the boot image. And if it isn't done now, then USB wouldn't have enough space after step-4.
	4)	Fills all the USB hardDisks found in step-2, with dummy files, so that it doesn't have free space more than 100MB. That way these drives wouldn't be chosen for 
		staging boot image as the criteria is it should at least have 400MB free space.
	
.PARAMETER
	<NONE>

	http://help.1e.com/display/WSS30/Creating%20OS%20Deployment%20task%20sequences
	
.ASSUMPTIONS
	Script is initiated by a TaskSequence
    
.INPUTS
	<NONE>

.OUTPUTS
	Following are possible exit codes
	0	-	On Success
	1	-	No TaskSequence Environment
	Other	-	Couldn't fill USB hardDisk or for some unknown reason

.CHANGELOG
    1. <DATE> - Description

.NOTES
  Version:        1
  Author:         Sravan Goud  
  Creation Date:  03-05-2018
  Last Modified Date:  03-05-2018
  Purpose/Change: Initial script development
#>
function GetEncryptionStatus($driveLetter)
{
	$encrytableVolume = Get-WmiObject -Query "select * from win32_encryptablevolume where DriveLetter = '$driveLetter'" -Namespace "root\cimv2\Security\MicrosoftVolumeEncryption" | select -First 1

	if($encrytableVolume -eq $null)
	{
		return $false;
	}

	$conversionStatus = $encrytableVolume.GetConversionStatus()
	if($conversionStatus -eq $null)
	{
		return $false;
	}

	return $conversionStatus.ConversionStatus -ne 0
}

function GetUSBHardDisks()
{
	return Get-WmiObject Win32_USBController | % {
	  $usbController = $_
	  $pnpEntities = "ASSOCIATORS OF " +
					"{Win32_USBController.DeviceID='$($usbController.DeviceID)'} " +
					"WHERE AssocClass = Win32_USBControllerDevice ResultClass = Win32_PnPEntity"
	  Get-WmiObject -Query $pnpEntities | % {
		$pnpEntity = $_
		$diskDrives = "ASSOCIATORS OF " +
				  "{Win32_PnPEntity.DeviceID='$($pnpEntity.DeviceID)'} " +
				  "WHERE AssocClass = Win32_PnPDevice ResultClass = Win32_DiskDrive"
	  Get-WmiObject -Query $diskDrives | % {
	  $disk = $_
	  $partitions = "ASSOCIATORS OF " +
					"{Win32_DiskDrive.DeviceID='$($disk.DeviceID)'} " +
					"WHERE AssocClass = Win32_DiskDriveToDiskPartition"
	  Get-WmiObject -Query $partitions | % {
		$partition = $_
		$drives = "ASSOCIATORS OF " +
				  "{Win32_DiskPartition.DeviceID='$($partition.DeviceID)'} " +
				  "WHERE AssocClass = Win32_LogicalDiskToPartition"
		Get-WmiObject -Query $drives | % {

			if($_.DriveType -eq 3)
			{
			  New-Object -Type PSCustomObject -Property @{
				Disk        = $disk.DeviceID
				DiskSize    = $disk.Size
				DiskModel   = $disk.Model
				Partition   = $partition.Name
				RawSize     = $partition.Size
				DriveLetter = $_.DeviceID
				VolumeName  = $_.VolumeName
				Size        = $_.Size
				FreeSpace   = $_.FreeSpace
				}
			}
		}
		}
		}
		}
		}
}

$tsenv = New-Object -COMObject Microsoft.SMS.TSEnvironment

if (-Not $tsenv)
{
	Write-host "No valid TS environment"
	exit 1
}

$tsDataPath = $tsenv.Value("_SMSTSMDataPath")
$tsDataDrive = Split-Path -Path $tsDataPath -Qualifier

$encryptionStatus = GetEncryptionStatus($tsDataDrive)
if(!$encryptionStatus)
{
	Write-Host "TS data path drive '$tsDataDrive' is not encrypted. Nothing to do"
	exit 0
}

$hardDisks = GetUSBHardDisks
if(!$hardDisks -or $hardDisks.Count -eq 0)
{
	Write-Host "Didn't find USB harddisk. Nothing to do"
	exit 0
}

$smsInstallPath = (Get-ItemProperty -Path Registry::"HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\SMS\Client\Configuration\Client Properties").'Local SMS Path'
write-host "SMS client is installed at '$smsInstallPath'"
$bootImageId = $tsenv.Value("_SMSTSBootImageID")
$smsswdArgs = "/run:$bootImageId  cmd.exe /c"
Write-Host $smsswdArgs
$smsswdProcess = start-process smsswd.exe -ArgumentList $smsswdArgs -PassThru -Wait -WorkingDirectory $smsInstallPath
	   
if($smsswdProcess.ExitCode -eq 0)
{        
	write-host ("smsswd.exe successfully downloaded boot image")         
}
else
{
	write-host ("smsswd.exe has failed error code $($smsswdProcess.ExitCode)")
	exit $smsswdProcess.ExitCode
}

$exitCode = 0
ForEach ($hardDisk in $hardDisks)
{
	Write-host "External harddisk with volume '$($hardDisk.DriveLetter)' and free space of $($hardDisk.FreeSpace)"
	$bootImageSize = 400MB

	if($hardDisk.FreeSpace -ge $bootImageSize)
	{
		Write-host "External harddisk with volume '$($hardDisk.DriveLetter)' has enough free space to hold boot image"
		$DummyFolder = $hardDisk.DriveLetter + "\1EWSA\_dummy_stuff"
		If(!(test-path $DummyFolder))
		{
			New-Item -ItemType Directory -Force -Path $DummyFolder
		}

		$DummyFilePath = $DummyFolder + "\" + [guid]::NewGuid()
		$fileSize = $hardDisk.FreeSpace - 100MB

		$Arguments = "file createnew $DummyFilePath $fileSize"
		Write-Host $Arguments
		$p = start-process fsutil.exe -ArgumentList $Arguments -PassThru -Wait
				
		if($p.ExitCode -eq 0)
		{        
			write-host ("Filling up the harddisk has succeeded")
			$tsenv.Value("1EWSA_USB_FilledUp") = "true";          
		}
		else
		{
			$exitCode = $p.ExitCode
			write-host ("Filling up the harddisk has failed error code $($p.ExitCode)")
			break
		}
	}
	else
	{
		Write-host "External harddisk with volume '$($hardDisk.DriveLetter)' isn't free enough to hold boot image"
	}
}

exit $exitCode
