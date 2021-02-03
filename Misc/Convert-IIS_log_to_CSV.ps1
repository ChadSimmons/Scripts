#.Synopsis
#  Convert IIS log file to CSV
#.LINK
#  Based on https://stevenaskwith.com/2012/05/22/parse-iis-log-files-with-powershell
#  Performance inspired by http://www.happysysadm.com/2014/10/reading-large-text-files-with-powershell.html
###########################################################################################################
#define the ConfigMgr Distribution Point's IIS log file to parse
$File = "C:\InetPub\Logs\LogFiles\W3SVC1\u_ex$(Get-Date -Format yyMMdd).log"
#read the 4th line in the most efficient way to generate an array of the column headers
$Headers = @((Get-Content -Path $File -ReadCount 4 -TotalCount 4)[3].split(' ') | Where-Object {$_ -ne '#Fields:'})
Write-Output "Reading $([math]::Round($(Get-Item -Path $File).length/1mb,1)) MB file..."
$FileCSV = Import-Csv -Delimiter ' ' -Header $Headers -Path $File | Where-Object {$_.date -notlike '#*'}
$FileCSV | Out-GridView -Title "IIS log: $File"
