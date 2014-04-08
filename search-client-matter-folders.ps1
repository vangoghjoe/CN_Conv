param ($clList, $outFile, $errFile)

write-host "$clList  $outFile  $errFile"

rm $outFile 2>&1 > $null
rm $errFile 2>&1 > $null

get-content $clList | % {
    write-host "Process dir $_"
    if (-not (test-path $_)) {
        "Folder not there: $_" | out-file -append -encoding ASCII $errFile
    }
    else {
        .\find-all-dcbs-just-file-name.ps1 $_ >> $outFile
    }
}


