
param(
    [Parameter(Mandatory=$true)]
    $BatchID,
    $ignoreStatus = $false,
    $DriverFile,
    $startRow,
    $endRow
)


. ((Split-Path $script:MyInvocation.MyCommand.Path) + "/libConversion.ps1")

# Take a file and return its size, or -1 if doesn't exist
function Get-File-Size($file) {

    # have to check $? *immediately* after call to test-path
    # can't even be like if (-not (test-path blut)) ...
    $mytest = test-path $file 2>$null
    $last = $?
    if (-not ($mytest)) {
        #write-host ("test-path neg: last val = " + $last + " $file")
        return @(-1, $last)
    }
    else {
        $len = (get-item $file).length
        return @($len, $true)
    }
}

# Take a type (db, natives, images)
# sets size/num_files in db
# makes a result file of missings
function Process-Type($type, $listFile, $sizesFilePFN, $missFilePFN, $statusFilePFN, $dbRow) {
    # Inits
    $line = 0
    $numMiss = 0
    $numPresent = 0
    $ttlSize = 0

    # read listFile and gather stats
    $files = get-content $listFile 
    foreach ($file in $files) {
        $line++

        # skip blank lines
        if ($file -match '^\s*$') {
            continue
        }

        try {
            ($size, $lastExitStat) = Get-File-Size $file
            
            # missing?
            if ($size -eq -1) {
                $numMiss++
                if ($lastExitStat -eq $false) {
                   $msg = "warning when testing path, probably too long or bad format"
                }
                else {
                   $msg = ""
                }
                CF-Write-File $missFilePFN (@($dbrow.dbid, $row.clientid, $dbrow.orig_dcb, $type, $file, $msg) -join "|")
            }
            else {
                $numPresent++
                $ttlSize += $size
            }
        }
        catch {
            CF-Write-File $statusFilePFN (@($dbrow.orig_dcb, $type, "ERROR", "ERROR") -join "`t")
        }
    }

    # Append results to $sizesFilePFN
    # dbid | clientid | orig_dcb | type | total size | num present | num missing
    CF-Write-File $sizesFilePFN (@($dbrow.dbid, $row.clientid, $dbrow.orig_dcb, $type, $ttlSize, $numPresent, $numMiss) -join "|")
    write-host "$(get-date): $($dbrow.dbid): ${type}: present = $numPresent  miss = $numMiss bytes = $ttlSize"
}

# Process the list files for a given row
# Verifies status of each type (db, natives and images) before calling
function Process-Row($dbRow, $runEnv) {

    # Inits
    $bStr = $runEnv.bStr
    $dbid = $dbRow.dbid
    $dcbPfn = $dbRow.conv_dcb;
    $dbStr = "{0:0000}" -f [int]$dbid

    # Loop over types, setting listFile and calling Process-Type
    foreach ($type in @("natives", "images")) {
        try {

            $script:rowHasError = $false
            # Init status file
            $statusFile = "${bStr}_${dbStr}_sizes_${type}_STATUS.txt"
            $script:statusFilePFN =  "$($runEnv.ProgramLogsDir)\$statusFile"
            CF-Initialize-Log $script:statusFilePFN
            
            # First init output files: sizes and miss
            # Remove them in case were there from previous runs
            $sizesFile = "${bStr}_${dbStr}_sizes_${type}.txt"
            $script:sizesFilePFN = "$($runEnv.SearchResultsDir)\$sizesFile"
            rm $sizesFilePFN 2>$null
            $missFile = "${bStr}_${dbStr}_miss_${type}.txt"
            $script:missFilePFN = "$($runEnv.SearchResultsDir)\$missFile"
            rm $missFilePFN 2>$null

            # Init input list file path
            if ($type -eq "images") {
                $listFile =   "${bStr}_${dbStr}_${type}_ALL.txt"
            }
            else {
                $listFile =   "${bStr}_${dbStr}_${type}.txt"
            }

            $listFilePFN = "$($runEnv.SearchResultsDir)\$listFile"


            if (test-path $listFilePFN) {
                CF-Initialize-Log $script:sizesFilePFN 
                CF-Write-File $script:sizesFilePFN "dbid | clientid | orig_dcb | type | total size | num present | num missing"

                CF-Initialize-Log $script:missFilePFN 
                CF-Write-File $script:missFilePFN "dbid | clientid | orig_dcb | type | file | msg"

                # do it
                Process-Type $type $listFilePFN $sizesFilePFN $missFilePFN $statusFilePFN $dbRow
            }
            else {
                # decided it should be an error to be asked to run when don't 
                # have correct input files.
                CF-Write-Log $script:statusFilePFN "|ERROR|The input list file for type '$type' is missing: $listFilePFN"
                $script:rowHasError = $true
            }
        }
        catch { # this try/catch is *inside* the types loop, b/c each get's its own
            CF-Write-File $errFile "|ERROR|$($error[0])"
            $script:rowHasError = $true
        }
        CF-Finish-Log $script:statusFilePFN 
    } # end for type
}

function Main {
    # Bare inits to write to master log
    $runEnv = CF-Init-RunEnv $BatchID
    CF-Log-To-Master-Log $runEnv.bstr "" "START" ""

    try {
        # Inits

        # Load driver file, if using
        if ($DriverFile) {
            CF-Load-Driver-File $DriverFile
        }

        $dcbRows = CF-Read-DB-File "DCBs" "BatchID" $BatchID

        #   Remove output files
        #$outFile = "${fileStub}.txt"
        #$missFile = "${fileStub}-miss.txt"
        #$errFile = "${fileStub}-err.txt"
        #foreach ($file in @($outFile, $missFile, $errFile)) {
            #rm $file 2>&1 > $null
        #}

        #   Setup start/stop rows (assume user specifies as 1-based)
        if ($startRow -eq $null) { $startRow = 1 }
        if ($endRow -eq $null) { $endRow = $dcbRows.length } 
        CF-Log-To-Master-Log $runEnv.bstr "" "STATUS" "Start row=$startRow  End row=$endRow"
         
        # Main loop
        for($i = ($startRow-1) ; $i -lt $endRow ; $i++) {
            $row = $dcbRows[$i]
            
            # Only process this row if it's in the right batch 
            # and has the right status
            if ($row.batchid -ne $BatchID) {
                continue
            }

            # Check against driver file, if using
            if ($DriverFile) {
                if (-not (CF-Is-DBID-in-Driver $row.dbid)) {
                    continue
                }
            }

            Process-Row $row $runEnv  
        }
    }
    catch {
        $error[0] | format-list
        CF-Log-To-Master-Log $runEnv.bstr "" "ERROR" "$($error[0])"
    }

    # Wrap up
    CF-Log-To-Master-Log $runEnv.bstr "" "STATUS" "STOP Start row=$startRow  End row=$endRow"
    $endDate = $(get-date -format $CF_DateFormat)
    write-host "*** Done: batch = $BatchID Start row=$startRow  End row=$endRow"
    write-host "Start: $startDate"
    write-host "End:   $endDate"
    if (-not $DriverFile ) { $DriverFile = "None" }
    write-host "Driver file = $DriverFile"
    CF-Log-To-Master-Log $runEnv.bstr "" "STATUS" "STOP"
}     

Main

