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
function Process-Row($dbRow, $runEnv) {
    # Inits
    CF-Init-RunEnv-This-Row $runEnv $dbRow

    # Inits
    $bStr = $runEnv.bStr
    $dbid = $dbRow.dbid
    $dcbPfn = $dbRow.conv_dcb;
    $dbStr = "{0:0000}" -f [int]$dbid

    # Loop over the programs (like run-get-images, run-get-natives)
    write-host "DBID = $dbid"
    try {
        foreach ($pgm in @("run-get-images", "run-get-images-pt2","run-get-natives")) {
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

            # Get status from log
            # If log not there at all, have to assume it didn't run, so status is empty
            if (-not (test-path $pgmStatusFilePFN)) {
                $dbRow.$pgmStatFld = ""
            }
            elseif (CF-Log-Says-Ran-Successfully $pgmStatusFilePFN) {
                $dbRow.$pgmStatFld = $CF_STATUS_GOOD
            }
            else {
                $dbRow.$pgmStatFld = $CF_STATUS_FAILED
                CF-Make-Global-Error-File-Record $pgm $dbRow $pgmStatusFilePFN $script:collectedErrLog
            }
        }
    }
    catch {
        CF-Write-Log $script:statusFilePFN "|ERROR|$($error[0])"
        $script:rowHasError = $true
    }
    CF-Finish-Log $script:statusFilePFN 
}

function Main {
    $runEnv = CF-Init-RunEnv $BatchID
    CF-Log-To-Master-Log $runEnv.bstr "" "STATUS" "START"

    try {
        # For this program, use a simple log file in curr dir to capture errors
        $script:statusFilePFN = "run-update-statuses-STATUS.txt"
        CF-Initialize-Log $statusFilePFN 

        # The log of the munged error lines from all the pgms we're looking at
        # It will also go in the curr dir
        $script:collectedErrLog = "collected-error-log-$($runEnv.bstr).txt"
        CF-Initialize-Log $collectedErrLog
        CF-Write-Log $collectedErrLog "PGM | DB_ID | CLIENT_ID | DCB | Timestampt | Err Msg" 

        $dcbRows = CF-Read-DB-File "DCBs" "BatchID" $BatchID

        # Setup start/stop rows (assume user specifies as 1-based)
        if ($startRow -eq $null) { $startRow = 1 }
        if ($endRow -eq $null) { $endRow = $dcbRows.length } 
        CF-Log-To-Master-Log $runEnv.bstr "" "STATUS" "Start row=$startRow  End row=$endRow"
         
        # Main loop
        for ($i = ($startRow-1) ; $i -lt $endRow ; $i++) {
            $row = $dcbRows[$i]
            
            # Only process this row if it's in the right batch 
            # and has the right status
            if ($row.batchid -ne $BatchID) {
                continue
            }
            # Status check is done on a per type basis in Process-Type
            #if (($row.$statusFld -eq $CF_STATUS_IN_PROGRESS) -or
                #($ignoreStatus=$false -and ($row.statusFld -eq $CF_STATUS_GOOD))) {
                #continue
            #}

            Process-Row $row $runEnv  

            # Write out whole DB every time in case stop before end of run
            CF-Write-DB-File "DCBs" $dcbRows
        }
    }
    catch {
        $error[0] | format-list
        CF-Log-To-Master-Log $runEnv.bstr "" "ERROR" "$($error[0])"
    }

    CF-Log-To-Master-Log $runEnv.bstr "" "STATUS" "STOP"

    write-host ""
    write-host "DONE"
}     

Main

