# you need to "source" this file, not "run" it. So, do this:
# . fix-path.ps1

function Add-To-Path {
	param ($dir)
	# for now, just blindly add it to the beginning without checking
	$env:path = "$dir; $env:path"
}

Add-To-Path 'C:\Documents and Settings\hudsonj1\My Documents\Hogan\Scripts'