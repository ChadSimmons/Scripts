'http://myitforum.com/myitforumwp/2012/06/20/how-to-list-task-sequence-environment-variables-and-values
'by Greg Ramsey

Set objTSEnv = CreateObject("Microsoft.SMS.TSEnvironment")
For Each objVar in objTSEnv.GetVariables
	wscript.echo objVar & "=" & objTSEnv(objVar)
Next

'==TODO==
' auto output to a log that gets captured
' handle cscript and wscript (can't do wscript.echo)
' add to all Task Sequences (before image deploys, after, and after each reboot)
' add to Environment variables on each boot: HostName, _SMSTSLogPath, OSDComputerName, ???
' add to GetLogs
' use Make, Model, OSDImageVersion, OSDImageCreator, ?? in SysImageInfo
