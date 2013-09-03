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
    $Backups,
    $startRow,
    $endRow
)


. ((Split-Path $script:MyInvocation.MyCommand.Path) + "/libConversion.ps1")



#for each step: get-images get-natives
#    need name of status file, name of status field
#    if has error, 
#        if not, set status ok 
#    else
#        write out the errors to a big file
#            dcb | type | error message   (what if multiple lines?)
#        set status to bad
#    
#for each step:  add images, add natives
#    if has error
#        if not, nothing to do
#    else
#        write out the errors to a big file
#            dcb | type | error message   (what if multiple lines?)
function Process-Cell($dbRow, $runEnv, $pgm) {
    # Inits
    CF-Init-RunEnv-This-Row $runEnv $dbRow

    # Inits
    $bStr = $runEnv.bStr
    $dbid = $dbRow.dbid
    $dcbPfn = $dbRow.conv_dcb;
    $dbStr = "{0:0000}" -f [int]$dbid

    write-host "DBID = $dbid"
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

        # if didn't have good backup, shouldn't have run the other code,
        # so take it out of error files
        if ($dbRow.backup_done -ne "1") {
            $dbRow.$pgmStatFld = ""
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
        #write-host "pgm: $pgm" # debug
        if (($pgm -eq "run-get-natives") -or ($pgm -eq "run-get-images-pt2")) {
            if ($dbRow.pgmStatFld -ne $CF_STATUS_GOOD) {
                $resFile = CF-Make-Output-PFN-Name $runEnv $CF_PGMS.$pgm[2] "search"
                # debug
                write-host "pgm: $pgm  resultsFile to kill = $resFile"
                write $resFile >> $script:resultsToRm 
                #rm $resFile 2>&1 > $null
            }
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
        $pgms = @("run-get-natives","run-get-images", "run-get-images-pt2")

        # For this program, use a simple log file in curr dir to capture errors
        $script:statusFilePFN = "run-update-statuses-STATUS.txt"
        CF-Initialize-Log $statusFilePFN 

        # List of results file to remove b/c had bad statuses
        # Once I'm confident in this list, can have the script do the remove
        $script:resultsToRm = "result-files-for-removal.txt"
        CF-Initialize-Log $resultsToRm

        $dcbRows = CF-Read-DB-File "DCBs" "BatchID" $BatchID

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
            $script:collectedErrLog = "errors-$($runEnv.bstr)-${pgm}.txt"
            CF-Initialize-Log $collectedErrLog
            CF-Write-File $collectedErrLog "PGM | DB_ID | CLIENT_ID | DCB | Timestampt | Err Msg" 

            # the Good log
            $script:collectedGoodLog = "good-$($runEnv.bstr)-${pgm}.txt"
            CF-Initialize-Log $collectedGoodLog
            CF-Write-File $collectedGoodLog "PGM | DB_ID | CLIENT_ID | DCB | Timestamp" 

            for ($i = ($startRow-1) ; $i -lt $endRow ; $i++) {
                $row = $dcbRows[$i]
                CF-Init-RunEnv-This-Row $runEnv $row
                
                # Only process this row if it's in the right batch 
                if ($row.batchid -ne $BatchID) {
                    continue
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

    CF-Log-To-Master-Log $runEnv.bstr "" "STATUS" "STOP"

    write-host ""
    write-host "DONE"
    write-host "See $resultsToRm for files to remove"
}     

Main

