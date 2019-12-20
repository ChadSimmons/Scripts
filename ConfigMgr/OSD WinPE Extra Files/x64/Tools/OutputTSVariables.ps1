#http://blogs.technet.com/b/mniehaus/archive/2009/09/22/running-powershell-scripts-as-part-of-a-task-sequence.aspx
# Determine where to do the logging
$tsenv = New-Object -COMObject Microsoft.SMS.TSEnvironment
$logPath = $tsenv.Value("_SMSTSLogPath")
$logFile = "$logPath\$($myInvocation.MyCommand).log"

# Start the logging
Start-Transcript $logFile

# Write all the variables and their values
$tsenv.GetVariables() | % { Write-Host "$_ = $($tsenv.Value($_))" }

# Stop logging
Stop-Transcript

write-host "Log file saved to:$logFile"