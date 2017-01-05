#$VerbosePreferenceBAK = $VerbosePreference
#$VerbosePreference = 'Continue'
$Debug = $false #$true

$PathRoot = 'D:\Pictures\Photo.Inbox\Import.20160000' #'F:\Pictures\Inbox\Move.now\PHOTO'
$DestinationRoot = $PathRoot
$i = 0
$files = Get-ChildItem -Path $PathRoot -File

#$file = $files | Where { $_.Name -like 'P*' } | Select -First 1
#$file
ForEach ($file in $files) {
    $i++; $isDay = $false
    Write-Progress -Activity 'Moving files based on name as date' -Status "File $i of $($files.Count)"
    
    #check for a file name like yyyyMMdd_*.*
    $Day = ($file.BaseName -split '_')[0]
    If ($isDay -eq $false -and $Day -gt 19000000 -and $Day -le (Get-Date -Format yyyyMMdd)) {
        $isDay = $true
        Write-Verbose "file $($file.Name) begins with what appears to be a date in the format of yyyyMMdd"
    }

    If ($isDay -eq $false) {
        #check for a file name like yyyyMMdd*.*
        If ([bool]$file.BaseName -as [double]) {  #isNumeric $file.BaseName
            $Day = ($file.BaseName).substring(0,8)
        }
        If ($Day -gt 19000000 -and $Day -le (Get-Date -Format yyyyMMdd)) {
            $isDay = $true
            Write-Verbose "file $($file.Name) begins with what appears to be a date in the format of yyyyMMdd"
        }
    }
<#
    If ($isDay -eq $false) {
        #check for a file name like PHOTO_yyyyMMdd_*.*

        file:///C:/Users/chsimmons/OneDrive/Chad-Work/Regular%20Expressions%20cheat%20sheet.pdf
        ($file.BaseName -match '^PHOTO_[1-2][0|9]\d\d\d\d\d\d_*')

        $Day = ($file.BaseName -split '_')[1]
        If ($Day -gt 19000000 -and $Day -le (Get-Date -Format yyyyMMdd)) {
            $isDay = $true
            Write-Verbose "file $($file.Name) begins with what appears to be a date in the format of [text]_yyyyMMdd_"
        }
    }
#>

    If ($Debug -ne $true) {
        If ($isDay -eq $true) {
            If (!(Test-Path -Path "$PathRoot\$Day")) {
                New-Item -Path $PathRoot -Name $Day -ItemType Directory
            }
            Write-Host "Move $($file.FullName) to $PathRoot\$Day"
            Move-Item -Path $file.FullName -Destination "$PathRoot\$Day"
        } else {
        }
    } else {
        Write-Host "if not in debug mode, would Move $($file.FullName) to $PathRoot\$Day"
    }
}
$VerbosePreference = 'SilentlyContinue' #$VerbosePreferenceBAK
