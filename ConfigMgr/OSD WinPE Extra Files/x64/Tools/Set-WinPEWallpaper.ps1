param(
	[Parameter(HelpMessage = 'Full path and name to the background picture file.')][string]$FilePath = 'X:\Windows\System32\WinPE.jpg',
	[Parameter(HelpMessage = 'Numeric file base name to the background picture file in the script path.')][int16]$ID
)
If ($PSBoundParameters.ContainsKey('ID')) {
	#https://stackoverflow.com/questions/801967/how-can-i-find-the-source-path-of-an-executing-script/6985381#6985381
	#https://stackoverflow.com/questions/1183183/path-of-currently-executing-powershell-script
	#$Invocation = (Get-Variable MyInvocation -Scope 1).Value; #$ScriptPath = Split-Path $Invocation.MyCommand.Path
	#$ScriptPath = Split-Path -parent $PSCommandPath
	$ScriptPath = Split-Path -Path $script:MyInvocation.MyCommand.Path -Parent
	$IDFile = Join-Path -Path $ScriptPath -ChildPath $([string]$ID + '.jpg')
	If (Test-Path -Path $IDFile -PathType Leaf) {
		$FilePath = $IDFile
	} Else {
		Write-Error "File [$IDFile] was not found.  Falling back to the default of [$FilePath]."
	}
}

$code = @'
using System.Runtime.InteropServices;
namespace Win32{   
    public class Wallpaper{
		[DllImport("user32.dll", CharSet=CharSet.Auto)]
		static  extern int SystemParametersInfo (int uAction , int uParam , string lpvParam , int fuWinIni) ;
		// ----------------------------------------------------------
        // FindWindow : http://msdn.microsoft.com/en-us/library/ms633499.aspx
        // ----------------------------------------------------------
        [DllImport("user32.dll", SetLastError = true)]
        internal static extern int FindWindow(string lpClassName, string lpWindowName);
        // ----------------------------------------------------------
        // Show Window : http://msdn.microsoft.com/en-us/library/ms633548.aspx
        // ----------------------------------------------------------
        [DllImport("user32.dll", SetLastError = true)]
        internal static extern int ShowWindow(int hwnd, int nCmdShow);
		public static void SetWallpaper(string thePath){
	        SystemParametersInfo(20,0,thePath,3);
			// ####################
		    // | Find Window
		    // ####################
		    int hwnd = FindWindow(null, "FirstUXWnd");
		    // ####################
		    // | Hide Window : 0 = Hide, 1 = Show
		    // ####################
		    if (hwnd != 0) ShowWindow(hwnd, 0);
    	}
    }
}
'@
add-type $code
new-itemproperty -path "HKCU:\Control Panel\Desktop" -Name "WallpaperStyle" -PropertyType "String" -Value "3" -Force
Write-Output "Setting Windows Desktop background to [$FilePath]."
[Win32.Wallpaper]::SetWallpaper("$FilePath")