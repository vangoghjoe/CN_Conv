# you need to "source" this file, not "run" it. So, do this:
# . fix-path.ps1

function Add-To-Path {
	param ($dir)
	# for now, just blindly add it to the beginning without checking
	$env:path = "$dir; $env:path"
}

$myhost = $(Get-WmiObject win32_computersystem).name
Add-To-Path "W:\_LN_Test\Scripts"
#Add-To-Path 'C:\Documents and Settings\hudsonj1\My Documents\Hogan\Scripts'
