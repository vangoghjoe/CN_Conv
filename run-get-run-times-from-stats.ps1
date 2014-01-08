[CmdLetBinding()]
param(
    $BatchID,
    $ignoreStatus = $false,
    $DriverFile,
    [switch]$pgmAll,
    [switch]$pgmBackup,
    [switch]$pgmBackupLocalv8,
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
    $DBid,
    $startRow,
    $endRow
)
set-strictmode -version 2

. ((Split-Path $script:MyInvocation.MyCommand.Path) + "/libConversion.ps1")

function Process-Cell($dbRow, $runEnv, $pgm, $type="status") {
    # Inits
    CF-Init-RunEnv-This-Row $runEnv $dbRow

    # Inits
    $bStr = $runEnv.bStr
    $bID = $runEnv.bID
    $dbid = $dbRow.dbid
    $dcbPfn = $dbRow.conv_dcb;
    $dbStr = "{0:0000}" -f [int]$dbid

    $script:rowHasError = $false
    $script:rowStatusGood = $false
    try {
        # Calc status field and status file
        $pgmStatFld = $CF_PGMS.$pgm[0];
        $pgmStatFileStub = $CF_PGMS.$pgm[1];
        $pgmStatusFile = "${bStr}_${dbStr}_${pgmStatFileStub}_STATUS.txt"
        $pgmStatusFilePFN =  "$($runEnv.ProgramLogsDir)\$pgmStatusFile"
        
        write-verbose "statusfile = $pgmStatusFilePFN"
        if (test-path $pgmStatusFilePFN) {
            ($start, $stop, $time) = CF-Get-Duration-For-Conv-Step $pgmStatusFilePFN
            # batch id, dbid, stat field, stat value
            $script:sqlUpdStat.CommandText = @"
UPDATE DCBs set conv_start='$start', conv_stop='$stop', conv_duration=$time
WHERE batchid = $bid and dbid = $dbid
"@
            $script:sqlUpdStat.ExecuteNonQuery() > $null
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
    $script:statusFilePFN = "run-get-rum-times-from-stats-STATUS.txt"

    try {
        # set up update status sql cmd
        $script:sqlUpdStat = CF-Get-SQL-Cmd $CF_DBName

        # set up @pgms

        $dcbRows = CF-Read-DB-File "DCBs" "BatchID" $BatchID

        # Setup start/stop rows (assume user specifies as 1-based)
        if ($startRow -eq $null) { $startRow = 1 }
        if ($endRow -eq $null) { $endRow = $dcbRows.length } 
        CF-Log-To-Master-Log $runEnv.bstr "" "STATUS" "Start row=$startRow  End row=$endRow"
         
        # Main loop
        $pgms = @("run-convert-one-dcb")
        foreach ($pgm in $pgms) {
            for ($i = ($startRow-1) ; $i -lt $endRow ; $i++) {
                $row = $dcbRows[$i]
                CF-Init-RunEnv-This-Row $runEnv $row

                $arrPreReqs = @()
                $arrPreReqs += $($row.st_convert_one_dcb)
                $noStatFld = $true
                if (CF-Skip-This-Row $runEnv $row $arrPreReqs $noStatFld) {
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

    # one last to make sure got all errors
    CF-Write-DB-File "DCBs" $dcbRows

    CF-Log-To-Master-Log $runEnv.bstr "" "STATUS" "STOP"

    write-host ""
    write-host "DONE"
}     

Main

