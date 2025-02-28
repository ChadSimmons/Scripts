#.Synopsis
#   Remove-MCMClientGUID.ps1
#.Notes
#   DO NOT RUN THIS ON A ConfigMgr Primary Site Server or any other computer which may have 'valuable' certificates in the SMS store'
#   TODO: Add detection and abort functionality if running on a ConfigMgr Site System Server
#.Link
#   Manual removal of the SCCM client https://blogs.technet.microsoft.com/michaelgriswold/2013/01/02/manual-removal-of-the-sccm-client/

=======================================================================================================================

Stop-Service -Name CcmSetup
Stop-Service -Name CcmExec
If ($Force) {
	Start-Process -FilePath "$env:SystemRoot\ccmsetup\ccmsetup.exe" -ArgumentList '/uninstall' -Wait
	Remove-Item -Path "$env:SystemRoot\ccm" -Recurse -Force
	Remove-Item -Path "$env:SystemRoot\ccmcache" -Recurse -Force
	Remove-Item -Path "$env:SystemRoot\ccmtemp" -Recurse -Force
	Remove-Item -Path "$env:SystemRoot\CCMSetup" -Recurse -Force
	#https://social.technet.microsoft.com/Forums/en-US/32264a03-1759-4a25-9b21-413c8de9fe4f/client-keeps-assigning-the-same-guid
	#clientidmanagerstartup "failed to cocreate as local server with error 0x80040154.  failling back to in-proc server"
	#https://hiraniconfigmgr.com/postDetails/22/Client-Register-keep-failing-with-0x80040154
	Remove-Item -Path "$envProgramData\Microsoft\Crypto\RSA\MachineKeys\19c5*" -Force
}
Remove-Item -Path "$env:SystemRoot\SMSCFG.ini" -Force
#Start-Process -FilePath 'certutil.exe' -ArgumentList '-delstore SMS SMS /F'
Get-ChildItem Cert:\LocalMachine\SMS\ | Where-Object {$_.Subject -like 'CN=SMS, CN=*'} | Remove-Item -Force
Remove-Item -Path 'HKLM:\Software\Microsoft\CCM\Security' -Recurse -Force
#Start-Process -FilePath 'reg.exe' -ArgumentList 'delete HKLM\Software\Microsoft\CCM\Security /F'
If ($Force) {
	#Start-Process -FilePath 'reg.exe' -ArgumentList 'delete HKLM\Software\Microsoft\CCM /F'
	#Start-Process -FilePath 'reg.exe' -ArgumentList 'delete HKLM\Software\Microsoft\SMS /F'
	#Start-Process -FilePath 'reg.exe' -ArgumentList 'delete HKLM\Software\Microsoft\CCMSetup /F'
	Remove-Item -Path 'HKLM:\Software\Microsoft\CCM' -Recurse -Force
	Remove-Item -Path 'HKLM:\Software\Microsoft\SMS' -Recurse -Force
	Remove-Item -Path 'HKLM:\Software\Microsoft\CCMSetup' -Recurse -Force
}
If ($Restart) {
   Start-Service -Name CcmExec
}

<#
=======================================================================================================================

$RemoteComputer = 'RemoteComputer1'
$Status = "Regenerating SMSGUID for computer $RemoteComputer"
Write-Progress -Status $Status -Activity 'Testing connection (WinRM)'
"Regenerating SMSGUID for computer $RemoteComputer"
If ((Test-NetConnection -Computer $RemoteComputer -CommonTCPPort WINRM).TcpTestSucceeded -eq 'True') {
        Write-Progress -Status $Status -Activity 'Creating PSSession connection'
        $myPSSession = New-PSSession -ComputerName $RemoteComputer
        #$myPSSession
        Get-PSSession -Id $myPSSession.Id
        Write-Progress -Status $Status -Activity 'Entering PSSession'
        Enter-PSSession -Session $myPSSession

        If ($env:ComputerName -like '*Server*') {
            Write-Error 'The remote computer is not right!'
        } else {
            $RemoteComputer = $env:ComputerName
            try {
                Write-Progress -Status $Status -Activity 'Deleting bad Certificate'
                Set-Location Cert:\LocalMachine\My\
                Get-ChildItem * | where {$_.Subject -like "CN=MyBadCert*"} | Remove-Item -Force

                Write-Progress -Status $Status -Activity 'Stopping ConfigMgr Client service'
                Stop-Service -Name CCMSetup -Force -ErrorAction SilentlyContinue
                Stop-Service -Name CcmExec -Force

                Write-Progress -Status $Status -Activity 'Deleting SMSCFG.ini'
                Set-Location 'C:\Windows'
                $SMSGUID = Get-Content 'C:\Windows\SMSCFG.ini' | Where { $_ -like 'SMS Unique Identifier*' }
                Remove-Item -LiteralPath "C:\Windows\SMSCFG.ini" -Force -Confirm:$false
                #sc.exe config "ccmexec" start= auto

                Write-Progress -Status $Status -Activity 'Deleting SMS certificates'
                Set-Location Cert:\LocalMachine\SMS\
                Get-ChildItem * | where {$_.Subject -like "CN=SMS*"} | Remove-Item -Force

                Write-Progress -Status $Status -Activity 'Restarting ConfigMgr Client service'
                Start-Service -Name CcmExec

                Write-Progress -Status $Status -Activity 'Waiting for regeneration of SMSCFG.ini'
                $i=0
                While (-not(Test-Path -Path 'C:\Windows\SMSCFG.ini')) {
                    Start-Sleep -Seconds 5
                    $i+= 5
                    Write-Progress -Status $Status -Activity 'Waiting for regeneration of SMSCFG.ini' -CurrentOperation 'Waiting $i seconds'
                }
                Start-Sleep -Seconds 5

                Write-Progress -Status $Status -Activity 'Getting new ConfigMgr SMSGUID and certificates'
                $SMSGUIDnew = Get-Content 'C:\Windows\SMSCFG.ini' | Where { $_ -like 'SMS Unique Identifier*' }

                Get-ChildItem * | where {$_.Subject -like "CN=SMS*"}
                Write-Output "Old SMSGUID: $SMSGUID"
                Write-Output "New SMSGUID: $SMSGUIDnew"
                If ($SMSGUID -eq $SMSGUIDnew) {
                    Write-Error "SMSGUID did not change"
                } else {
                    Write-Output "New SMSGUID created"
                }
                Write-Progress -Status $Status -Activity 'Exiting and deallocating PSSesson'

            } catch {}
        }
        Exit-PSSession
        Remove-PSSession -Session $myPSSession
} Else {
	Write-Warning "Computer $RemoteComputer is not accessible over WinRM"
}

#>
