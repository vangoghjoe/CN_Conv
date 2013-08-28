param (
    $dbList,
    $outFile
    )

. ((Split-Path $script:MyInvocation.MyCommand.Path) + "/libConversion.ps1")

function Main() {
    # Inits
    if (test-path $outFile) { clear-content $outFile }
    CF-Write-File (@("DCB","Size in Bytes","Num Files") -join "`t")
    $ttlSize = $numFiles = 0
    
    # For each dcb
    $dcbs = get-content $dbList
    write-host "num files in list = $($files.length)"
    foreach ($dcb in $dcbs) {
        # Get the dir
        $dir = [system.io.path]::GetDirectoryName($dcb)

        # If present, get size: else leave size blank
        ($size, $numFiles) = CF-Get-Num-Files-And-Size-Of-Folder $dir
        $ttlSize += $size
        $ttlNumFiles += $numFiles

        # Write $db  $size $numFiles, tab delimited 
        $msg = (@($dcb, $size, $numFiles) -join "`t")
        write-host $msg
        CF-Write-File $outFile $msg
    }
    # Wrap up
    #   Write totals to file and to screen
    $msg = (@("", $ttlSize, $ttlNumFiles) -join "`t")
    Write-host $msg
    CF-Write-File $outFile $msg
}

Main
