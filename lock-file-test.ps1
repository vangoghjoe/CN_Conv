$fh = [system.io.file]::Open("DCBs.txt", 'Open', 'ReadWrite', 'None')
$r = New-Object System.IO.StreamReader($fh)
$s = $r.readtoend()
$csv = $s | convertFrom-Csv -delim "`t"
$csv
$fh.close()
""