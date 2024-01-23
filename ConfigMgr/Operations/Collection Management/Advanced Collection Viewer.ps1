#.Synopsis
#   Advanced Collection Viewer.ps1
#   Quickly Change Limiting Collection and Incremental Updates on Collections
#.Description
#   This tool shows you all the collections in your environment and gives you 
#   the ability to quickly change the limtiing collection and / or incremental 
#   updates. This tool will also show you information about power plans, maintenance 
#   windows, and collection variables to help you hunt down problem collections.
#.Link
#   https://gallery.technet.microsoft.com/Quickly-Change-Limiting-3a68944a
#.Note
#   2016/03/23 by Chad.Simmons@CatapultSystems.com - added export function
#   2015/03/04 by Ryan Ephgrave - Created
#>
$Popup = New-Object -ComObject wscript.shell

Write-Host "Importing ConfigMgr Cmdlets..."
Import-Module ($env:SMS_ADMIN_UI_PATH.Substring(0,$env:SMS_ADMIN_UI_PATH.Length - 5) + '\ConfigurationManager.psd1') -ErrorAction SilentlyContinue | Out-Null

Function LoadWPFControls {
    Param ($XAML)
    $XAML = $XAML.OuterXML
    $SplitXaml = $xaml.Split("`n")
    foreach ($Line in $SplitXaml) {
        if ($Line.ToLower().Contains("x:name")) {
    		$SplitLine = $Line.Split("`"")
    		$Count = 0
    		foreach ($instance in $SplitLine) {
    			$Count++
    			if ($instance.ToLower().Contains("x:name")) {
    				$ControlName = $SplitLine[$Count]
                    $strExpression = "`$SyncTable.$ControlName = `$SyncTable.Window.FindName(`"$ControlName`")"
                    Invoke-Expression $strExpression
    			}
    		}
    	}
    }
}

Function Get-Information {
    Param ($Server, $SiteCode, $objType)
    Write-Host "Loading collection information..."
    $SyncTable.ColList = New-Object System.Collections.Arraylist
    $strQuery = "Select * from SMS_Collection"
    Switch ($objType) {
        "User Collections" {$strQuery = $strQuery + " where Col.CollectionType = '1'"}
        "Device Collections" {$strQuery = $strQuery + " where Col.CollectionType = '2'"}
    }
    
    $ContainerObjects = Get-WmiObject -Namespace "root\sms\site_$SiteCode" -ComputerName $Server -Class SMS_ObjectContainerNode
    Get-WmiObject -Namespace "root\sms\site_$SiteCode" -ComputerName $Server -Query $strQuery | ForEach-Object {
        $Result = Select-Object -InputObject "" Name, Type, LimitCol, IncrementalUpdates, Power, MemberCount, MaintenanceWindows, ColVariable
        $Result.Name = $_.Name
        If ($_.CollectionType -eq "1") {$Result.Type = "User"}
        else {$Result.Type = "Device"}
        $Result.LimitCol = $_.LimitToCollectionName
        $Result.MemberCount = $_.MemberCount
        $Result.Power = $_.PowerConfigsCount
        $Result.MaintenanceWindows = $_.ServiceWindowsCount
        $Result.ColVariable = $_.CollectionVariablesCount
        If (($_.RefreshType -eq "6") -or ($_.RefreshType -eq "4")) {$Result.IncrementalUpdates = "Yes"}
        $SyncTable.ColList += $Result
    }
    #$SyncTable.Data_ColList.ItemsSource = $SyncTable.ColList
    Write-Host "Finished gathering collection information!"
    Return $SyncTable.ColList
}

Function Load-Information {
    Param ($Server, $SiteCode, $objType)
    $CollectionList = Get-Information -Server $Server -SiteCode $SiteCode -objType $objType
    $SyncTable.Data_ColList.ItemsSource = $CollectionList
    Write-Host "Loaded collection information!"
}

Function Export-Information {
    Param ($Server, $SiteCode, $objType)
    $CollectionList = Get-Information -Server $Server -SiteCode $SiteCode -objType $objType

    #region... Generate a Save File As dialog
    #.Synopsis GUI-FileSaveDialog.ps1 
    #.Link     https://gallery.technet.microsoft.com/scriptcenter/GUI-popup-FileSaveDialog-813a4966
    #.Author   Dan Stolts - dstolts$microsoft.com - http://ITProGuru.com
    $SaveFileDialog = New-Object windows.forms.savefiledialog   
    $SaveFileDialog.initialDirectory = [System.IO.Directory]::GetCurrentDirectory()   
    $SaveFileDialog.title = "Save File to Disk"   
    $SaveFileDialog.filter = "CSV Files|*.csv|All Files|*.*" 
    $SaveFileDialog.ShowHelp = $True   
    Write-Host "Where would you like to save the collection details file?... (see File Save Dialog)" -ForegroundColor Green  
    $result = $SaveFileDialog.ShowDialog()    
    $result 
    if($result -eq "OK")    {    
            Write-Host "Selected File and Location:"  -ForegroundColor Green  
            $SaveFileDialog.filename   
    } else { 
        Write-Host "File Save Dialog Cancelled!" -ForegroundColor Yellow
    }
    #$SaveFileDialog.Dispose() 
    #endregion

    $CollectionList | Export-Csv -Path "$($SaveFileDialog.filename)" -NoTypeInformation
    Write-Host "Finished exporting collection information!"
}

Function ChangeCollections {
    Param ($Server, $SiteCode, $ChkLimitCol, $TxtLimitCol, $ChkIncremental, $OptionIncremental, $SelectedCols, $objType)
    $Cd = "$SiteCode" + ":\"
    CD $Cd
    $ColList = ""
    Foreach ($Col in $SelectedCols) {
        $ColList = $ColList + $Col.Name + "`n"
    }
    If ($ChkLimitCol) {
        $tempCheckCol = $null
        $tempCheckCol = (Get-WmiObject -Namespace "root\sms\site_$SiteCode" -ComputerName $Server -Query "Select Name from SMS_Collection where name like '$TxtLimitCol'").Name
        If ($tempCheckCol -ne $null) {
            $Answer = $Popup.Popup("Do you want to change the limiting collection to $TxtLimitCol of these collections?`n$ColList",0,"",1)
            If ($Answer -eq 1) {
                Foreach ($instance in $SelectedCols) {
                    $ColName = $instance.Name
                    Write-Host "Changing limiting collection of $ColName"
                    If ($instance.Type -eq "Device") {Set-CMDeviceCollection -Name $ColName -LimitingCollectionName $TxtLimitCol}
                    elseif ($instance.Type -eq "User") {If ($instance.Type -eq "Device") {Set-CMUserCollection -Name $ColName -LimitingCollectionName $TxtLimitCol}}
                }
            }
        }
        Else {$Popup.Popup("Error, Limiting Collection does not exist!",0,"Error",16)}
    }
    If ($ChkIncremental) {
        $Answer = $Popup.Popup("Do you want to turn Incremental Updates $OptionIncremental on these collections?`n$ColList",0,"Are you sure?",1)
        If ($Answer -eq 1) {
            Foreach ($instance in $SelectedCols) {
                $ColName = $instance.Name
                Write-Host "Changing incremental updates to $OptionIncremental of $ColName"
                Get-WmiObject -Namespace "root\sms\site_$sitecode" -ComputerName $Server -Query "Select * from SMS_Collection where Name like '$ColName'" | ForEach-Object {
                    $_.Get()
                    If ($OptionIncremental -eq "Off") {
                        If ($_.RefreshType -eq 4) {
                            $_.RefreshType = 1
                            $_.Put()
                        }
                        elseif ($_.RefreshType -eq 6) {
                            $_.RefreshType = 2
                            $_.Put()
                        }
                    }
                    elseif ($OptionIncremental -eq "On") {
                        If ($_.RefreshType -eq 1) {
                            $_.RefreshType = 4
                            $_.Put()
                        }
                        elseif ($_.RefreshType -eq 2) {
                            $_.RefreshType = 6
                            $_.Put()
                        }
                    }
                }
            }
        }
    }
    Write-Host "Finished changing collections!"
    Load-Information -Server $Server -SiteCode $SiteCode -objType $objType
}

Function Get-CMFolderStructure {
    Param ($ContainerNodeID, $ObjectID = $null, $count = 0, $ContainerPath = "", $ContainerObjects = $null, $Namespace, $Server)
    $count++
    If ($ObjectID -ne $null) {$ContainerNodeID = (Get-WmiObject -Namespace $Namespace -ComputerName $Server -Query "Select ContainerNodeID From SMS_ObjectContainerItem WHERE InstanceKey = '$ObjectID'").ContainerNodeID}
    If ($ContainerObjects -eq $null) {$ContainerObjects = Get-WmiObject -Namespace $Namespace -ComputerName $Server -Class SMS_ObjectContainerNode}
    Foreach ($instance in $ContainerObjects) {
        If ($instance.ContainerNodeID -eq $ContainerNodeID) {
            If ($instance.ParentContainerNodeID -ne 0) {$ContainerPath = Get-CMFolderStructure -ContainerPath $ContainerPath -ContainerObjects $ContainerObjects -Server $Server -Namespace $Namespace -ContainerNodeID $instance.ParentContainerNodeID -count $count}
            If ($ContainerPath -eq "") {$ContainerPath = $instance.Name}
            else {$ContainerPath = $ContainerPath + "\" + $instance.Name}
        }
    }
    return $ContainerPath
}

$Global:SyncTable = [HashTable]::Synchronized(@{})
Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase

[XML]$xaml = @'
<Window
        xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Change Collection Settings" SizeToContent="WidthAndHeight" ResizeMode="NoResize" >
    <StackPanel>
        <StackPanel Orientation="Horizontal" Margin="5,5,5,5">
            <Label Content="CM Server Name:" Margin="5,5,5,5" HorizontalAlignment="Left" VerticalAlignment="Top"/>
            <TextBox x:Name="Txt_CMServer" Height="23" TextWrapping="NoWrap" Text="" Width="150"/>
            <Label Content="CM Site Code:" Margin="5,5,5,5" HorizontalAlignment="Left" VerticalAlignment="Top"/>
            <TextBox x:Name="Txt_CMSiteCode" Height="23" TextWrapping="NoWrap" Text="" Width="75" Margin="5,5,5,5"/>
            <Button x:Name="Btn_LoadCol" Content="Load Collections" Width="110" Height="25"/>
            <Button x:Name="Btn_ExportCol" Content="Export Collections" Width="110" Height="25"/>
        </StackPanel>
        <StackPanel Orientation="Horizontal">
            <Label Content="Collection Types To Show" Margin="5,5,5,5"/>
            <ComboBox x:Name="Combo_ColTypes" Width="150" Height="23" Margin="5,5,5,5" HorizontalContentAlignment="Center">
                <ComboBoxItem Content="All Collections" HorizontalContentAlignment="Center" IsSelected="True"/>
                <ComboBoxItem Content="User Collections" HorizontalContentAlignment="Center"/>
                <ComboBoxItem Content="Device Collections" HorizontalContentAlignment="Center"/>
            </ComboBox>
        </StackPanel>
        <DataGrid x:Name="Data_ColList" IsReadOnly="True" ItemBindingGroup="{Binding}" AutoGenerateColumns="False" SelectionUnit="FullRow" HeadersVisibility="Column" HorizontalAlignment="Stretch" VerticalAlignment="Top" Height="400" Margin="5,5,5,5">
            <DataGrid.Columns>
                <DataGridTextColumn Binding="{Binding Path=Name}" Header="Name"/>
                <DataGridTextColumn Binding="{Binding Path=Type}" Header="Type"/>
                <DataGridTextColumn Binding="{Binding Path=MemberCount}" Header="Member Count"/>
                <DataGridTextColumn Binding="{Binding Path=LimitCol}" Header="Limiting Collection"/>
                <DataGridTextColumn Binding="{Binding Path=IncrementalUpdates}" Header="Incremental Updates"/>
                <DataGridTextColumn Binding="{Binding Path=Power}" Header="Power Plan Count"/>
                <DataGridTextColumn Binding="{Binding Path=MaintenanceWindows}" Header="Maintenance Window Count"/>
                <DataGridTextColumn Binding="{Binding Path=ColVariable}" Header="Collection Variable Count"/>
            </DataGrid.Columns>
        </DataGrid>
        <StackPanel Orientation="Horizontal">
            <CheckBox x:Name="Chk_LimitCol" Content="Change the limiting collection:" VerticalContentAlignment="Center" Height="23" Margin="5,5,5,5"/>
            <TextBox x:Name="Txt_LimitCol" Width="350" Height="23" TextWrapping="NoWrap" AcceptsReturn="False" VerticalContentAlignment="Center" Margin="5,5,5,5"/>
        </StackPanel>
        <StackPanel Orientation="Horizontal">
            <CheckBox x:Name="Chk_Incremental" VerticalContentAlignment="Center" Height="23" Margin="5,5,5,5" Content="Change incremental Updates:"/>
            <ComboBox x:Name="Combo_Incremental" Width="120" Height="23" Margin="5,5,5,5">
                <ComboBoxItem Content="On" HorizontalContentAlignment="Center"/>
                <ComboBoxItem Content="Off" HorizontalContentAlignment="Center"/>
            </ComboBox>
        </StackPanel>
        <Button x:Name="Btn_Start" Width="75" Height="23" Margin="5,5,5,5" Content="Start"/>
    </StackPanel>
</Window>
'@

$XMLReader = (New-Object System.Xml.XmlNodeReader $xaml)
$SyncTable.Window = [Windows.Markup.XamlReader]::Load($XMLReader)
LoadWPFControls $XAML

$SyncTable.Btn_LoadCol.Add_Click({
    Load-Information -Server $SyncTable.Txt_CMServer.Text -SiteCode $SyncTable.Txt_CMSiteCode.Text -objType $SyncTable.Combo_ColTypes.SelectedItem.Content
})


$SyncTable.Btn_ExportCol.Add_Click({
    Export-Information -Server $SyncTable.Txt_CMServer.Text -SiteCode $SyncTable.Txt_CMSiteCode.Text -objType $SyncTable.Combo_ColTypes.SelectedItem.Content
})

$SyncTable.Btn_Start.Add_Click({
    ChangeCollections -Server $SyncTable.Txt_CMServer.Text -SiteCode $SyncTable.Txt_CMSiteCode.Text -ChkLimitCol $SyncTable.Chk_LimitCol.IsChecked -TxtLimitCol $SyncTable.Txt_LimitCol.Text -ChkIncremental $SyncTable.Chk_Incremental.IsChecked -OptionIncremental $SyncTable.Combo_Incremental.SelectedItem.Content -SelectedCols $SyncTable.Data_ColList.SelectedItems -objType $SyncTable.Combo_ColTypes.SelectedItem.Content
})

$SyncTable.Window.ShowDialog() | Out-Null