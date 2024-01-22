Function Create-RandomFiles{
#.SYNOPSIS
#	Generates a number of dumb files for a specific size.
#.DESCRIPTION
#	Generates a defined number of files until reaching a maximum size.
#.PARAMETER TotalSize
#	Specify the total size you would all the files combined should use on the harddrive.
#	This parameter accepts the following size values (KB,MB,GB,TB).  MB is assumed if no designation is specified.
#		200KB
#		5MB
#		3GB
#		1TB
#.PARAMETER NumberOfFiles
#	Specify a number of files that need to be created. This can be used to generate
#	a big number of small files in order to simulate User backup specific behavior.
#.PARAMETER OldestTime
#    This parameter is not mandatory, but set the oldest timestamp of newly created files to the date specified.
#    If not specified, the date will be set to now
#.PARAMETER NewestTime
#    This parameter is not mandatory, but set the newest timestamp of newly created files to the date specified.
#    If not specified, the date will be set to now
#.PARAMETER FilesTypes
#    This parameter is not mandatory, but the following choices are valid to generate files with the associated extensions:
#        Multimedia, Image, Office, Windows, Office, Junk Archive, Misc, Script, All
#	If FilesTypes parameter is not set, by default, the script will create all types of files.
#.PARAMETER Path
#    Specify a path where the files should be generated.
#.PARAMETER NamePrefix
#    Optional.  Allows prepending text to the beginning of the generated file names so they can be easily found and sorted.
#.PARAMETER WhatIf
#    Permits to launch this script in "draft" mode. This means it will only show the results without really making generating the files.
#.PARAMETER Verbose
#    Allow to run the script in verbose mode for debugging purposes.
#.EXAMPLE
#   .\Create-RandomFiles.ps1 -TotalSize 1GB -NumberOfFiles 123 -Path $env:Temp -FilesTypes 'Office' -NamePrefix '~'
#   Generate in the user's temp folder 123 randomly named office files all beginning with "~" which total 1GB.
#.EXAMPLE
#   .\Create-RandomFiles.ps1 -TotalSize 50 -NumberOfFiles 42 -Path C:\Users\administrator\documents
#   Generate in the administrator's documents folder 42 randomly named files which total 50MB.
#.NOTES
#   This script is maintained at https://github.com/ChadSimmons/Scripts
#   Additional information about the function or script.
#   ========== Keywords ==========
#   Keywords: USMT User State Migration random demo sample files
#   ========== Change Log History ==========
#   - 2019/06/xx by Chad Simmons - added OldestTime, NewestTime, additional file types
#   - 2015/12/04 by Chad.Simmons - added Write-Progress, files are created with different sizes, TotalSize defaults to MB, added name prefix, added execution statistics, replaced fsutil.exe with New-Object byte[], added additional filetypes
#   - 2015/12/04 by Chad.Simmons@CatapultSystems.com - forked from http://powershelldistrict.com/create-files/
#    - Author: Stephane van Gulick, Svangulick@gmail.com
#    - Version: 1.0
#        -Creation V0.1 : SVG
#        -First final draft V0.5 : SVG
#        -Corrected minor bugs V0.6 : SVG
#        -Functionalized the script V0.8 : SVG
#        -Simplified code V1.0 : SVG
#   === To Do / Proposed Changes ===
#   - TODO: reconcile file types
[cmdletbinding(SupportsShouldProcess=$true)]
param(
    [Parameter(mandatory=$true)][int32]$NumberOfFiles,
	[Parameter(mandatory = $true)][ValidateScript( { [IO.Directory]::Exists($_) })][System.IO.DirectoryInfo]$Path,
    [Parameter(mandatory=$true)][string]$TotalSize,
    [Parameter(mandatory=$false)][datetime]$OldestTime = $(Get-Date),
    [Parameter(mandatory=$false)][datetime]$NewestTime = $(Get-Date),
    [Parameter(mandatory=$false)][validateSet('Multimedia','Image','Office','Junk','Archive','Script','Misc','all','')][String]$FilesType = 'all',
    [Parameter(mandatory=$false)][string]$NamePrefix = ''
)

Begin {
    $StartTime = (get-date)
    $TimeSpan = New-TimeSpan -Start $StartTime -end $(Get-Date) #New-TimeSpan -seconds $(($(Get-Date)-$StartTime).TotalSeconds)
    $Progress=@{Activity = 'Create Random Files...'; Status='Initializing...'}
    Write-verbose 'Generating files'
    Write-Verbose -Message "Oldest Timestamp will be $OldestTime"
    Write-Verbose -Message "Newest Timestamp will be $NewestTime"
    If ($TotalSize -match '^\d+$') { [string]$TotalSize += 'MB' } #if TotalSize isNumeric (did not contain a byte designation, assume MB
    $Progress.Status="Creating $NumberOfFiles files totalling $TotalSize"
    Write-Progress @Progress

    Write-Verbose "Total Size is $TotalSize"
    $FileSize = $TotalSize / $NumberOfFiles
    $FileSize = [Math]::Round($FileSize, 0)
    Write-Verbose "Average file size of $FileSize"
    $FileSizeOffset = [Math]::Round($FileSize/$NumberOfFiles, 0)
    Write-Verbose "file size offset of $FileSizeOffset"
    $FileSize = $FileSizeOffset*$NumberOfFiles/2
    Write-Verbose "Beginning file size of $FileSize"

    Function Set-FileExtensionList {
        [CmdletBinding()]
        param(
            [Parameter(mandatory = $false)][validateSet('Multimedia', 'Image', 'Office', 'Junk', 'Archive', 'Script', 'Misc', 'all', '')][String]$FilesType = $FilesType
        )
        Write-Verbose 'Creating file extension list'
        #Extensions for Music and Videos... use VLC for a near definitive list
        $script:MultimediaExtensions = '.mp4', `
                            #Music
                            '.ac3','.adt','.adts','.aif','.aifc','.aiff','.amr','.asx','.au','.cda','.ec3','.ecw','.flac','.m1v','.m3u','.m4a', `
                            '.m4b','.m4p','.mid','.mka','.mp2','.mp3','.mpa','.ogg','.rmi','.snd','.wav','.wax','.wmd','.wmx','.wpl','.wvx', `
                            '.midi','.mpeg2','.mpeg3','.ram','.rm','.wma', `
                            #Video
                            '.3g2','.3gp','.3gp2','.3gpp','.asf','.avi','.divx','.flv','.m1v','.m2t','.m2ts','.m2v','.m4v','.mka','.mkv','.mod', `
                            '.mov','.mp2v','.mp4','.mp4v','.mpeg','.mpg','.mpv2','.mts','.tod','.ts','.webm','.wmv','.xvid'
        #Extensions for Photos and Pictures
        #TODO: add common RAW extensions... use IrfanView for a near definitive list
        $script:ImageExtensions   = '.emz','.svg','.svgz','.dwg','.dxf','.raw','.eps','.pcx','.3gpp','.b3d','.bmp','.clp','.cr2','.crw','.cur', `
                            '.dcx','.dib','.emf','.eps','.g3','.gif','.ico','.iff','.ima','.jls','.jng','.jp2','.jpc','.jpe','.jpeg','.jpg', `
                            '.jxr','.kdc','.mng','.pbm','.pcd','.pcx','.pgm','.png','.ppm','.psd','.raw','.rgb','.rle','.sgi','.swf','.tga', `
                            '.tif','.tiff','.wdp','.wmf','.xbm','.xpm'
        #TODO: Extensions for Windows built-in applications including Paint 3d, contacts, Remote Desktop Connection, etc., etc.
        #TODO: Primary extensions for Word, PowerPoint, Excel, Outlook, Access, Visio, Project, Publisher, OneNote, Adobe Acrobat, and OpenOffice
        $script:OfficeExtensions  = '.pdf','.doc','.docx','.xls','.xlsx','.ppt','.pptx'
        #TODO: Secondary extensions for Word, PowerPoint, Excel, Outlook, Access, Visio, Project, Publisher, OneNote, Adobe Acrobat, and OpenOffice
        $script:OfficeExtensions2 = '.rtf','.txt','.csv','.xml','.mht','.mhtml','.htm','.html','.xps', `
                            '.dot','.dotx','.docm','.dotm','.odt','.wps', `
                            '.xlt','.xltx','.xlsm','.xlsb','.xltm','.xla','.ods','.xht','.xhtml','.xl','.xla','.xlam','.xlk','.xll','.xlm','.xls','.xlsb','.xlshtml','.xlsm','.xlsx','.xlt','.xlthtml','.xltm','.xltx','.xlw','.xl_', `
                            '.pot','.potx','.pptm','.potm','.pps','.ppsx','.ppsm','.odp','.pot','.pothtml','.potx','.pot_','.ppa','.ppam','.pps','.ppsm','.ppsx','.pps_','.pptm','.pptmhtml','.pptxml','.ppt_', `
                            '.pub','.mpp','.vsd','.vsdx','.vsdm','.vdx','.vssx','.vssm','.vsx','.vstx','.vst','.vstm','.vsw','.vdw', `
                            '.dochtml','.docm','.docx','.docxml','.doc_','.dot','.dothtml','.dotm','.dotx','.dot_', `
                            '.accda','.accdb','.accdc','.accde','.accdr','.accdt','.accdu','.accdw','.accft'
        $script:OfficeExtensions  += $OfficeExtensions2
        $script:JunkExtensions    = '.tmp','.temp','.lock'
        #Extensions for other registered file types
        $script:MiscExtensions = '.xml','.xps','.xsl','.ica','.3mf','.adn','.adp','.c','.cpp','.cs','.cdmp','.cer','.ch3','.chm','.cilx','.citrixonline','.contact','.cpl','.cr','.dctx','.dctxc','.desktopthemepack','.dfwx','.dhp','.diagcab''.diagcfg','.diagpkg','.dic','.dif','.dos',`
                            '.dqy','.drv-ms','.easmx','.edrws','.elm','.enl','.enl_','.eprtx','.epub','.evt','.evtx','.exc','.fbx','.fdm','.fh','.fon','.frm','.frm_','.g2m','.gcsx','.glb','.gltf','.gmmp','.gotomeeting','.gqsx','.gra','.group','.hol','.hta',`
                            '.htm','.html','.htm_','.icl','.icm','.ics','.igp','.inf','.ini','.iqy','.jar','.jpl','.jse','.jtx','.lnk','.log','.lo_','.mad','.maf','.mag','.mam','.maq','.mar','.mas','.mat','.mav','.maw','.mcw','.mda','.mdb','.mdbhtml',`
                            '.mde','.mdn','.mdt','.mdw','.mht','.mhtml','.mk3d','.mlc','.mpp','.msc','.msg','.MYD','.MYD_','.MYI','.MYI_','.nfo','.odc','.odp','.odt','.oft','.ols','.one','.onepkg','.onetoc','.onetoc2','.one_','.opt','.opt_','.oqy','.or6',`
                            '.oxps','.p12','.p7b','.p7c','.pbk','.pdf_','.pre','.pst','.ptom','.pub','.qdf','.qel','.qph','.qsd','.rdp','.reg','.rels','.rqy','.rtf','.scd','.sh3','.shtml','.sldm','.sldx','.slk','.snip','.snippet','.sql','.stl','.svg','.tar',`
                            '.tgz','.theme','.themepack','.thmx','.tsv','.ttc','.txt','.udl','.url','.vbe','.vbproj','.vbs','.vcf','.vcs','.vdw','.vdx','.vl','.vl_','.vsd','.vsdm','.vsdx','.vss','.vssm','.vssx','.vst','.vstm','.vsto','.vstx','.vsx','.vtx',`
                            '.wab','.wbcat','.wbk','.wbx','.website','.wiz','.wizhtml','.wk','.wks','.wk_','.wms','.wmz','.wpd','.wps','.wq1','.wri','.wsc','.wsf','.wsh','.wtx','.xaml','.zpl'
        $script:ArchiveExtensions = '.zip','.7z','.rar','.cab','.iso','.001','.ex_','.arj','.bzip2','.gzip','.lzma','.tpz','.xar','.vhd','.wim'
        $script:ScriptExtensions  = '.ps1','.vbs','.vbe','.cmd','.bat','.php','.hta','.ini','.inf','.reg','.asp','.sql','.vb','.js','.css','.kix','.au3','.ps1xml','.psc1','.psd1','.psm1'
        $script:AllExtensions = @()
        $script:AllExtensions = $MultimediaExtensions + $ImageExtensions + $OfficeExtensions + $JunkExtensions + $ArchiveExtensions + $ScriptExtensions + $MiscExtensions
        #TODO: remove duplicates
	}

    Function New-FileName {
        [CmdletBinding()]
        param(
            [Parameter(mandatory=$false)][validateSet('Multimedia','Image','Office','Junk','Archive','Script','Misc','all','')][String]$FilesType = $FilesType,
		    [Parameter(mandatory=$false)]$NamePrefix = $NamePrefix
        )
        #Generate a list of name using PowerShell verbs to choose from... do this only once per script session
        If (-not(Test-Path -Path 'variable:script:VerbList')) { $script:VerbList = (Get-Verb).verb }
        #Generate a list of file extensions to choose from... do this only once per script session
        If (-not($AllExtensions.count -gt 0)) { Set-FileExtensionList }

        #Get a random file extension
		switch ($filesType) {
			'Multimedia' {$extension = $MultimediaExtensions | Get-Random -Count 1 }
			'Image'      {$extension = $ImageExtensions | Get-Random -Count 1 }
			'Office'     {$extension = $OfficeExtensions | Get-Random -Count 1 }
			'Junk'       {$extension = $JunkExtensions | Get-Random -Count 1 }
			'Archive'    {$extension = $ArchiveExtensions | Get-Random -Count 1}
			'Misc   '    {$extension = $MiscExtensions | Get-Random -Count 1 }
			'Script'     {$extension = $ScriptExtensions | Get-Random -Count 1 }
			default      {$extension = $AllExtensions | Get-Random -Count 1 }
        }

        #Get a random set of names
		$Name = (Get-Random -InputObject $VerbList -Count 2) -join ''

        #combine the NamePrefix, the selected random name(s) and the file extension
		Write-Verbose 'Creating random file Name'
        [string]$FullName = $NamePrefix + $name + $extension
		Write-Verbose "File name created : $FullName"
		Write-Progress @Progress -CurrentOperation "Created file Name : $FullName"
		return [string]$FullName
    }
}
    #----------------Process-----------------------------------------------
process {
    $AllCreatedFilles = @()
    While ($FileNumber -lt $NumberOfFiles) {
        $FileNumber++
        If ($FileNumber -eq $NumberOfFiles) {
            $FileSize = $TotalSize - $TotalFileSize
            Write-Verbose "Setting last file to size $FileSize"
        }
        $TotalFileSize = $TotalFileSize + $FileSize
        Remove-Variable -Name FileName -ErrorAction SilentlyContinue
        [string]$FileName = New-FileName -filesType $filesType
        Write-Verbose "Creating : file named [$FileName] of $FileSize bytes"
        $Progress.Status="Creating $NumberOfFiles files totalling $TotalSize.  Run time $(New-TimeSpan -Start $StartTime -end $(Get-Date))"
        Write-Progress @Progress -CurrentOperation "Creating file $FileNumber of $NumberOfFiles : $FileName is $FileSize bytes" -PercentComplete ($FileNumber/$NumberOfFiles*100)

        $FullPath = Join-Path -Path $Path -ChildPath $FileName
        Write-Verbose "Generating file : $FullPath of $Filesize"
        try {
            #fsutil.exe file createnew $FullPath $FileSize | Out-Null
            $buffer=New-Object byte[] $FileSize  #http://blogs.technet.com/b/heyscriptingguy/archive/2010/06/09/hey-scripting-guy-how-can-i-use-windows-powershell-2-0-to-create-a-text-file-of-a-specific-size.aspx
            $fi=[io.file]::Create($FullPath)
            $fi.Write($buffer,0,$buffer.length)
            $fi.Close()
        } catch { $_ }
        try{ #set modified time stamp
            $Timestamp = new-object Datetime (Get-Random -Minimum $OldestTime.ticks -Maximum $NewestTime.ticks)
            (Get-Item -Path $FullPath).LastWriteTime = $Timestamp
        } catch { $_ }
        $Properties = @{'FullPath'=$FullPath;'Size'=$FileSize; 'Timestamp'=$Timestamp}
        $FileCreated = New-Object -TypeName psobject -Property $properties
        $AllCreatedFilles += $FileCreated
        Write-verbose "$($AllCreatedFilles) created $($FileCreated)"
        Write-Progress @Progress -CurrentOperation "Creating file $FileNumber of $NumberOfFiles : $FileName is $FileSize bytes.  Done." -PercentComplete ($FileNumber/$NumberOfFiles*100)
        $FileSize = ([Math]::Round($FileSize, 0)) + $FileSizeOffset
    }
}
end {
    Write-Output $AllCreatedFilles
    Write-Output "`nStart     time: $StartTime"
    Write-Output "Execution time: $(New-TimeSpan -Start $StartTime -end $(Get-Date))" #http://blogs.technet.com/b/heyscriptingguy/archive/2013/03/15/use-powershell-and-conditional-formatting-to-format-time-spans.aspx
}
}
