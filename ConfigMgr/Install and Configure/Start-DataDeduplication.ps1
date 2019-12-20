#Force Data Deduplication job to run now
Import-Module deduplication
$Drive = 'I:'
Get-DedupStatus -Volume $Drive | Format-List
Start-DedupJob -Volume $Drive -Type Optimization -Preempt -Wait
Get-DedupStatus -Volume $Drive | Format-List