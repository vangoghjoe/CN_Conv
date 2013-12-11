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
    [switch]$pgmFoldersNatives,
    [switch]$pgmFoldersImages,
    [switch]$pgmQcV8Tags,
    [switch]$pgmConvDcb,
    [switch]$pgmQcV10Tags,
    [switch]$pgmQcCompareTags,
    [switch]$incBlankStatus,
    $startRow,
    $endRow
)


. ((Split-Path $script:MyInvocation.MyCommand.Path) + "/libConversion.ps1")


function Build-List-Of-Pgms() {
    $pgms = @();
    if ($pgmBackup) { $pgms += "backup-for-conversion"; }
    if ($pgmNatives) { $pgms += "run-get-natives"; }
    if ($pgmImages) { $pgms += "run-get-images"; }
    if ($pgmImages2) { $pgms += "run-get-images2"; }
    if ($pgmFoldersNatives) { $pgms += "run-get-natives-folders"; }
    if ($pgmFoldersImages) { $pgms += "run-get-images-folders"; }
    if ($pgmQcV8Tags) { $pgms += "run-qc-v8-tags"; }
    if ($pgmConvDcb) { $pgms += "run-convert-one-dcb"; }
    if ($pgmQcV10Tags) { $pgms += "run-qc-v10-tags"; }
    if ($pgmQcCompareTags) { $pgms += "run-qc-compare-tags"; }
    if ($pgmSizesAll) { 
        $pgms += "run-check-and-add-sizes-to-file-natives"; 
        $pgms += "run-check-and-add-sizes-to-file-images"; 
    }
    return $pgms;
}


function Process-Cell($dbRow, $runEnv, $pgm, $type="status") {
    # Inits
    CF-Init-RunEnv-This-Row $runEnv $dbRow

    # Inits
    $bStr = $runEnv.bStr
    $dbid = $dbRow.dbid
    $dcbPfn = $dbRow.conv_dcb;
    $dbStr = "{0:0000}" -f [int]$dbid

    $script:rowHasError = $false
    $script:rowStatusGood = $false
    write-host "DBID = $dbid  pgm = $pgm"
    try {
        # Calc status field and status file
        $pgmStatFld = $CF_PGMS.$pgm[0];
        $pgmStatFileStub = $CF_PGMS.$pgm[1];
        if ($type -eq "status") {
            $pgmStatusFile = "${bStr}_${dbStr}_${pgmStatFileStub}_STATUS.txt"
            $pgmStatusFilePFN =  "$($runEnv.ProgramLogsDir)\$pgmStatusFile"
        }
        elseif ($type -eq "results") {
            $pgmStatFld += "_results"
            $pgmStatusFile = "${bStr}_${dbStr}_${pgmStatFileStub}.txt"
            $pgmStatusFilePFN =  "$($runEnv.SearchResultsDir)\$pgmStatusFile"
        }

        # DEBUG SECTION
        #write-host "pgm = $pgm"
        #write-host "statfld = $pgmStatFld"
        #write-host "stub = $pgmStatFileStub"
        #write-host "statfile = $pgmStatusFilePFN"

        # Get status from log
        # If log not there at all, have to assume it didn't run, so status is empty
        if (-not (test-path $pgmStatusFilePFN)) {
            $dbRow.$pgmStatFld = ""
            if ($incBlankStatus) {
                CF-Make-Global-Error-File-Record $pgm $dbRow $pgmStatusFilePFN $script:collectedErrLog $true
            }
        }
        elseif (CF-Log-Says-Ran-Successfully $pgmStatusFilePFN) {
            $dbRow.$pgmStatFld = $CF_STATUS_GOOD
            $script:rowStatusGood = $true
            CF-Make-Global-Good-File-Record $pgm $dbRow $pgmStatusFilePFN $script:collectedGoodLog
        }
        else {
            $dbRow.$pgmStatFld = $CF_STATUS_FAILED
            CF-Make-Global-Error-File-Record $pgm $dbRow $pgmStatusFilePFN $script:collectedErrLog
        }

    }
    catch {
        CF-Write-Log $script:statusFilePFN "|ERROR|$($error[0])"
        $script:rowHasError = $true
    }
    CF-Finish-Log $script:statusFilePFN 
}

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
                # Also check results, if applicable
                # Only check the results if the pgm itself
                # ran ok, meaning rowHasError = $false
                if ($script:rowStatusGood -eq $true) {  
                    if ($pgm -eq "run-qc-compare-tags") {
                        Process-Cell $row $runEnv $pgm "results"
                    }
                }

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
        if (($row.st_backup -eq $CF_STATUS_GOOD) -and 
            ($row.st_qc_compare_tags_results -eq $CF_STATUS_GOOD)
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

