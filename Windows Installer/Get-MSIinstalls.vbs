'from Office scrubber vbs
Set oMsi        = CreateObject("WindowsInstaller.Installer")
Sub CheckForLegacyProducts
    Const OLEGACY = "78E1-11D2-B60F-006097C998E7}.6000-11D3-8CFE-0050048383C9}.6000-11D3-8CFE-0150048383C9}.BDCA-11D1-B7AE-00C04FB92F3D}.6D54-11D4-BEE3-00C04F990354}"
    Dim Product
    
    'Set safe default
    fLegacyProductFound = True
    
    For Each Product in oMsi.Products
wscript.echo Product
wscript.echo Product.ProductInfo
        If Len(Product) = 38 Then
            'Handle O09 - O11 Products
            If InStr(OLEGACY, UCase(Right(Product, 28))) > 0 Then
                'Found legacy Office product. Keep flag in default and exit
                Exit Sub
            End If
            If UCase(Right(Product,PRODLEN)) = OFFICEID Then
                Select Case Mid(Product,4,2)
                Case "12", "14"
                    wscript.echo "Found legacy Office product."
                    'Exit Sub
                Case Else
                End Select
            End If
        End If '38
    Next 'Product
    fLegacyProductFound = False
    
End Sub 'CheckForLegacyProducts

CheckForLegacyProducts