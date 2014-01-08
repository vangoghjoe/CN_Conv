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
    [Parameter(mandatory=$true)]
    $BatchID,
    [Parameter(mandatory=$true)]
    [string] $FileStub,
    [switch]$NotJustErrors,
    [switch]$pgmAll,
    [switch]$pgmBackup,
    [switch]$pgmBackupLocalV8,
    [switch]$pgmNatives,
    [switch]$pgmImages,
    [switch]$pgmImages2,
    [switch]$pgmSizesAll,
    [switch]$pgmFoldersNatives,
    [switch]$pgmFoldersImages,
    [switch]$pgmQcV8Tags,
    [switch]$pgmQcListDictV8,
    [switch]$pgmQcQueryDictV8,
    [switch]$pgmQcPickWords,
    [switch]$pgmConvDcb,
    [switch]$pgmQcV10Tags,
    [switch]$pgmQcListDictV10,
    [switch]$pgmQcQueryDictV10,
    [switch]$pgmQcCompareTags,
    [switch]$pgmQcCompareDict,
    [switch]$incBlankStatus,
    [switch]$pgmConvReport,
    $startRow,
    $endRow,
    $ignoreStatus = $false,
    $DriverFile
)
set-strictmode -version 2

. ((Split-Path $script:MyInvocation.MyCommand.Path) + "/libConversion.ps1")


function Build-List-Of-Pgms() {
    $pgms = @();
    if ($pgmAll) {
        $pgms  += "backup-for-conversion"
        $pgms  += "backup-for-conversion-local-v8"
        $pgms  += "run-qc-v8-tags"
        $pgms  += "run-qc-list-dict-v8"
        $pgms  += "run-qc-dict-pick-qc-words"
        $pgms  += "run-qc-query-dict-v8"
        $pgms  += "run-convert-one-dcb"
        $pgms  += "run-qc-v10-tags"
        $pgms  += "run-qc-list-dict-v10"
        $pgms  += "run-qc-query-dict-v10"
        $pgms  += "run-qc-compare-tags"
        $pgms  += "parse-conversion-report"
        $pgms  += "run-qc-compare-dict"
    }
    else {
        if ($pgmBackup) { $pgms += "backup-for-conversion"; }
        if ($pgmBackup) { $pgms += "backup-for-conversion-local-v8"; }
        if ($pgmQcV8Tags) { $pgms += "run-qc-v8-tags"; }
        if ($pgmQcListDictV8) { $pgms += "run-qc-list-dict-v8"; }
        if ($pgmQcPickWords) { $pgms += "run-qc-dict-pick-qc-words"; }
        if ($pgmQcQueryDictV8) { $pgms += "run-qc-query-dict-v8"; }
        if ($pgmConvDcb) { $pgms += "run-convert-one-dcb"; }
        if ($pgmQcV10Tags) { $pgms += "run-qc-v10-tags"; }
        if ($pgmQcListDictV10) { $pgms += "run-qc-list-dict-v10"; }
        if ($pgmQcQueryDictV10) { $pgms += "run-qc-query-dict-v10"; }
        if ($pgmQcCompareTags) { $pgms += "run-qc-compare-tags"; }
        if ($pgmQcCompareDict) { $pgms += "run-qc-compare-dict"; }
        if ($pgmConvReport) { $pgms += "parse-conversion-report"; }
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
    try {
        # Calc status field and status file
        write-host "PROGRAM $pgm"
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

        # if NotJustErros, reset for all 
        # else only if currently = STATUS_FAILED
        write-host "DBID = $dbid  pgm=$pgm old stat=$($dbrow.$pgmStatFld)"
        if ($NotJustErrors -or ($dbRow.$pgmStatFld -eq $CF_STATUS_FAILED)) {
            write-host "clear it"
            $dbRow.$pgmStatFld = $CF_STATUS_READY
            echo "removing $pgmStatusFilePFN"
            remove-item -force $pgmStatusFilePFN -ea silentlycontinue > $null
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
            }
        }

        # Write out whole DB every time in case stop before end of run
        CF-Write-DB-File "DCBs" $dcbRows
    }
    catch {
        $error[0] | format-list
        CF-Log-To-Master-Log $runEnv.bstr "" "ERROR" "$($error[0])"
    }

}     

Main


