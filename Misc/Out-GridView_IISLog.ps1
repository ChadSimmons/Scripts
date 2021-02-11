Function Out-GridViewIISLog ($File) {
	#.Synopsis
	#  Convert IIS log file to CSV and display in a GridView
	#.LINK
	#  Based on https://stevenaskwith.com/2012/05/22/parse-iis-log-files-with-powershell/
	#  Performance inspired by http://www.happysysadm.com/2014/10/reading-large-text-files-with-powershell.html
	###########################################################################################################
	$Headers = @((Get-Content -Path $File -ReadCount 4 -TotalCount 4)[3].split(' ') | Where-Object { $_ -ne '#Fields:' });
	Import-Csv -Delimiter ' ' -Header $Headers -Path $File | Where-Object { $_.date -notlike '#*' } | Out-GridView -Title "IIS log: $File";
};
Out-GridViewIISLog -File "C:\InetPub\Logs\LogFiles\W3SVC1\u_ex$(Get-Date -F 'yyMMdd').log"
