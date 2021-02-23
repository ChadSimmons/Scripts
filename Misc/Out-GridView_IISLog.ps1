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


Function Out-GridViewIISLogEx { 
	#.Synopsis
	#  Convert IIS log file to CSV and display in a GridView
	#.LINK
	#  Based on https://stevenaskwith.com/2012/05/22/parse-iis-log-files-with-powershell/
	#  Performance inspired by http://www.happysysadm.com/2014/10/reading-large-text-files-with-powershell.html
	###########################################################################################################
	param ($File, $ContentLike, $ClientIPLike, $TCPPort, [switch]$Unique, 
		[parameter()][ValidateSet('*','ccmhttp','SMS+CCM+5.0+TS','Microsoft+BITS','DeliveryOptimization')][string]$ClientUserAgent = '*'
	)
	$Headers = @((Get-Content -Path $File -ReadCount 4 -TotalCount 4)[3].split(' ') | Where-Object { $_ -ne '#Fields:' });
	$Content = Import-Csv -Delimiter ' ' -Header $Headers -Path $File | Where-Object { $_.date -notlike '#*' };
	Write-Verbose -Message "Found $($Content.count) log lines" 
	If (-not([string]::IsNullOrEmpty($ContentLike))) { $Content = $Content | Where-Object { $_.'cs-uri-stem' -like "$ContentLike"}; Write-Verbose -Message "Found $($Content.count) filtered log lines" };
	If (-not([string]::IsNullOrEmpty($ClientIPLike))) { $Content = $Content | Where-Object { $_.'c-ip' -like "$ClientIPLike" }; Write-Verbose -Message "Found $($Content.count) filtered log lines" };
	If (-not([string]::IsNullOrEmpty($TCPPort))) { $Content = $Content | Where-Object { $_.'s-port' -eq $TCPPort }; Write-Verbose -Message "Found $($Content.count) filtered log lines" };
	If ($ClientUserAgent) { 
		Switch ($ClientUserAgent) {
			'ccmhttp' { $Content = $Content | Where-Object { $_.'cs(User-Agent)' -eq 'ccmhttp' } };
			'SMS+CCM+5.0+TS' { $Content = $Content | Where-Object { $_.'cs(User-Agent)' -eq 'SMS+CCM+5.0+TS' } };
			'Microsoft+BITS' { $Content = $Content | Where-Object { $_.'cs(User-Agent)' -like 'Microsoft+BITS*' } };
			'DeliveryOptimization' { $Content = $Content | Where-Object { $_.'cs(User-Agent)' -eq 'Microsoft Delivery Optimization/10.0' } };
			Default {}
		};
		Write-Verbose -Message "Found $($Content.count) filtered log lines" -Verbose
	};
	If ($Unique) { $Content = $Content | Select-Object -Unique;  Write-Verbose -Message "Found $($Content.count) unique log lines" -Verbose } Else { Write-Verbose -Message "Found $($Content.count) filtered log lines" -Verbose };
	If ($Content.count -ne 0) { $Content | Out-GridView -Title "IIS log: $File" };
};
Out-GridViewIISLogEx -File "D:\Logs\IIS\W3SVC1\u_ex210218.log" -ClientUserAgent DeliveryOptimization -Unique -ContentLike '*KB*' -TCPPort 80 -ClientIPLike '10.10.10.*'
