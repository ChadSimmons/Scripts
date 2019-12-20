;AutoItSetOption ("WinTitleMatchMode", 3)
$DialogTitle = "Error Applying Attributes"
$IdentifyingText = "Access is denied."
While 1 ;run forever
	If WinWait($DialogTitle, $IdentifyingText, 5) <> 0 Then ;wait up to 30 seconds for the dialog box with the title and text to exist
		ControlClick($DialogTitle, $IdentifyingText, "[CLASS:Button; INSTANCE:1]") ;click the button to Ignore
	EndIf
WEnd