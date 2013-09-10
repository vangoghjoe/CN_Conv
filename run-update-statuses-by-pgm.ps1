<#
SYNOPSIS 

.DESCRIPTION

.PARAMETER Name

.PARAMETER Extension

.INPUTS
None. You cannot pipe objects to this script

.OUTPUTS

.EXAMPLE
One or more examples

.EXAMPLE

.LINK

.LINK

#>

param(
    $BatchID,
    $ignoreStatus = $false,
    $DriverFile,
    [Parameter(mandatory=$true)]
    [string] $FileStub,
    [switch]$pgmBackup,
    [switch]$pgmNatives,
    [switch]$pgmImages,
    [switch]$pgmImages2,
    [switch]$pgmSizesAll,
    $startRow,
    $endRow
)


. ((Split-Path $script:MyInvocation.MyCommand.Path) + "/libConversion.ps1")


function Build-List-Of-Pgms() {
    $pgms = @();
    if ($pgmBackup) { $pgms += "backup-for-archiving"; }
    if ($pgmNatives) { $pgms += "run-get-natives"; }
    if ($pgmImages) { $pgms += "run-get-images"; }
    if ($pgmImages2) { $pgms += "run-get-images2"; }
    if ($pgmSizesAll) { 
        $pgms += "run-check-and-add-sizes-to-file-natives"; 
        $pgms += "run-check-and-add-sizes-to-file-images"; 
    }
    return $pgms;
}

#"natives_bytes",
#"natives_files_present",
#"natives_files_missing",
function Process-Sizes($dbRow, $runEnv, $pgm) {
    # Inits
    $bStr = $runEnv.bStr
    $dbid = $dbRow.dbid
    $dcbPfn = $dbRow.conv_dcb;
    $dbStr = "{0:0000}" -f [int]$dbid

    $pgmSizeFileStub = $CF_PGMS.$pgm[2];
    $pgmSizeFile = "${bStr}_${dbStr}_${pgmSizeFileStub}.txt"
    $pgmSizeFilePFN =  "$($runEnv.SearchResultsDir)\$pgmSizeFile"

    # get type
    if ($pgm -match "native") { $type = "natives" }
    elseif ($pgm -match "image") { $type = "images" }

    # get name of size file, will either have native or image in name
    # status file like sizes_images_STATUS.txt
    # size file like sizes_images.txt

    # make names of statistics fields
    $bytes_field = "${type}_bytes"
    $files_present_field = "${type}_files_present"
    $files_missing_field = "${type}_files_missing"

    # read second line
    if (-not (test-path $pgmSizeFilePFN)) { 
        throw "Error: $type size file missing: $pgmSizeFilePFN"
        return
    }

    $recs = get-content $pgmSizeFilePFN
    $rec = $recs[1] # just need the 2nd line

    # field struc: dbid | clientid | orig_dcb | type | total size | num present | num missing
    $fields = $rec -split "\|"
    $dbRow.$bytes_field = $fields[4]
    $dbRow.$files_present_field = $fields[5]
    $dbRow.$files_missing_field = $fields[6]
}


function Process-Cell($dbRow, $runEnv, $pgm) {
    # Inits
    CF-Init-RunEnv-This-Row $runEnv $dbRow

    # Inits
    $bStr = $runEnv.bStr
    $dbid = $dbRow.dbid
    $dcbPfn = $dbRow.conv_dcb;
    $dbStr = "{0:0000}" -f [int]$dbid

    write-host "DBID = $dbid  pgm = $pgm"
    try {
        # Calc status field and status file
        $pgmStatFld = $CF_PGMS.$pgm[0];
        $pgmStatFileStub = $CF_PGMS.$pgm[1];
        $pgmStatusFile = "${bStr}_${dbStr}_${pgmStatFileStub}_STATUS.txt"
        $pgmStatusFilePFN =  "$($runEnv.ProgramLogsDir)\$pgmStatusFile"

        # DEBUG SECTION
        #write-host "pgm = $pgm"
        #write-host "statfld = $pgmStatFld"
        #write-host "stub = $pgmStatFileStub"
        #write-host "statfile = $pgmStatusFilePFN"

        # TODO: consider clearing it's status if the pgm's it depenends on haven't run
        # For now, just leave the stub of the if/else
        # 2nd question: if get-natives or get-images2 aren't good, should it should remove
        # any entries from the 
        if ( 0 ) {
        }
        else {
            # Get status from log
            # If log not there at all, have to assume it didn't run, so status is empty
            if (-not (test-path $pgmStatusFilePFN)) {
                $dbRow.$pgmStatFld = ""
            }
            elseif (CF-Log-Says-Ran-Successfully $pgmStatusFilePFN) {
                $dbRow.$pgmStatFld = $CF_STATUS_GOOD
                CF-Make-Global-Good-File-Record $pgm $dbRow $pgmStatusFilePFN $script:collectedGoodLog
            }
            else {
                $dbRow.$pgmStatFld = $CF_STATUS_FAILED
                CF-Make-Global-Error-File-Record $pgm $dbRow $pgmStatusFilePFN $script:collectedErrLog
            }
        }

        # if pgm = get-natives or get-images-pt2, remove their SearchResults files 
        # unless status = good
        if (($pgm -eq "run-get-natives") -or ($pgm -eq "run-get-images-pt2")) {
            if ($dbRow.pgmStatFld -ne $CF_STATUS_GOOD) {
                $resFile = CF-Make-Output-PFN-Name $runEnv $CF_PGMS.$pgm[2] "search"
                # debug
                write $resFile >> $script:resultsToRm 
                #rm $resFile 2>&1 > $null
            }
        }

        # get sizes 
        if (($pgm -match "check-and-add") -and ($dbRow.$pgmStatFld -eq $CF_STATUS_GOOD)) {
            Process-Sizes $dbRow $runEnv $pgm
        }
    }
    catch {
        CF-Write-Log $script:statusFilePFN "|ERROR|$($error[0])"
        $script:rowHasError = $true
    }
    CF-Finish-Log $script:statusFilePFN 
}

# OK, super kludgy:  Loop over whole DB once for each pgm
# For each row, call Process-Cell to just that pgm for just that row
# So Process-Cell is called  #rows x #pgms times
function Main {
    $runEnv = CF-Init-RunEnv $BatchID
    CF-Log-To-Master-Log $runEnv.bstr "" "STATUS" "START"

    try {
        # set up @pgms
        $pgms = Build-List-Of-Pgms

        # For this program, use a simple log file in curr dir to capture errors
        $script:statusFilePFN = "run-update-statuses-STATUS.txt"
        CF-Initialize-Log $statusFilePFN 

        # List of results file to remove b/c had bad statuses
        # Once I'm confident in this list, can have the script do the remove
        $script:resultsToRm = "result-files-for-removal.txt"
        CF-Initialize-Log $resultsToRm

        # Load driver file, if using
        if ($DriverFile) {
            CF-Load-Driver-File $DriverFile
        }

        $dcbRows = CF-Read-DB-File "DCBs" "BatchID" $BatchID

        # snippet to put in error*/good* files
        if ($FileStub) { $FileStub = "-${FileStub}" }

        # Setup start/stop rows (assume user specifies as 1-based)
        if ($startRow -eq $null) { $startRow = 1 }
        if ($endRow -eq $null) { $endRow = $dcbRows.length } 
        CF-Log-To-Master-Log $runEnv.bstr "" "STATUS" "Start row=$startRow  End row=$endRow"
         
        # Main loop
        # Super inefficient, but easiest way to re-write
        # Now, Process-Cell is really acting like a Process-Cell, b/c it's called 
        #
        foreach ($pgm in $pgms) {
            # The log of the munged error lines from all the pgms we're looking at
            # It will also go in the curr dir  
            $script:collectedErrLog = "errors-$($runEnv.bstr)${FileStub}-${pgm}.txt"
            CF-Initialize-Log $collectedErrLog
            CF-Write-File $collectedErrLog "PGM | DB_ID | CLIENT_ID | DCB | Timestampt | Err Msg" 

            # the Good log
            $script:collectedGoodLog = "good-$($runEnv.bstr)${FileStub}-${pgm}.txt"
            CF-Initialize-Log $collectedGoodLog
            CF-Write-File $collectedGoodLog "PGM | DB_ID | CLIENT_ID | DCB | Timestamp" 

            for ($i = ($startRow-1) ; $i -lt $endRow ; $i++) {
                $row = $dcbRows[$i]
                CF-Init-RunEnv-This-Row $runEnv $row

                # Only process this row if it's in the right batch 
                if ($row.batchid -ne $BatchID) {
                    continue
                }

                # Check against driver file, if using
                if ($DriverFile) {
                    if (-not (CF-Is-DBID-in-Driver $row.dbid)) {
                        continue
                    }
                }

                Process-Cell $row $runEnv $pgm

            }
        }

        # Write out whole DB every time in case stop before end of run
        CF-Write-DB-File "DCBs" $dcbRows
    }
    catch {
        $error[0] | format-list
        CF-Log-To-Master-Log $runEnv.bstr "" "ERROR" "$($error[0])"
    }

    # Now, update st_size_all and st_all
    # st_size_all is good if both size_native and size_images are good
    # st_all is 2 if all statuses are good
    for ($i = ($startRow-1) ; $i -lt $endRow ; $i++) {
        $row = $dcbRows[$i]

        # Only process this row if it's in the right batch 
        if ($row.batchid -ne $BatchID) {
            continue
        }

        # Check against driver file, if using
        if ($DriverFile) {
            if (-not (CF-Is-DBID-in-Driver $row.dbid)) {
                continue
            }
        }

        write-host "update st_all: DBID = $($row.dbid)"

        #if (($row.st_size_natives -eq $CF_STATUS_GOOD) -and 
            #($row.st_size_images -eq $CF_STATUS_GOOD)
            #) {
            #$row.st_size = $CF_STATUS_GOOD
        #}
        #else {
            #$row.st_size = ""
        #}

        # update st_all
        if (($row.st_backup_arch -eq $CF_STATUS_GOOD) -and 
            ($row.st_get_natives -eq $CF_STATUS_GOOD) -and
            ($row.st_get_images -eq $CF_STATUS_GOOD) -and
            ($row.st_get_images2 -eq $CF_STATUS_GOOD) -and
            ($row.st_db_sizes -eq $CF_STATUS_GOOD) -and
            ($row.st_sizes_images -eq $CF_STATUS_GOOD) -and
            ($row.st_sizes_natives -eq $CF_STATUS_GOOD)
           )
        {
            $row.st_all = $CF_STATUS_GOOD
        }
        else {
            $row.st_all = $CF_STATUS_FAILED
        }

    }
    # one last to make sure got all errors
    CF-Write-DB-File "DCBs" $dcbRows

    CF-Log-To-Master-Log $runEnv.bstr "" "STATUS" "STOP"

    write-host ""
    write-host "DONE"
    write-host "See $resultsToRm for files to remove"
}     

Main

