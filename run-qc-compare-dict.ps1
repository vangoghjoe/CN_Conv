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
[CmdLetBinding()]
param(
    $BatchID,
    $startRow,
    $endRow,
    [switch] $ignoreStatus,
    $DriverFile,
    $DBId
)

set-strictmode -version latest

. ((Split-Path $script:MyInvocation.MyCommand.Path) + "/libConversion.ps1")

function Get-Num-Words-In-Dict($dbRow, $runEnv, $Vstr) {
    # Calc results file for the v8/10 tag pgms
    $bid = $dbRow.batchid
    $dbid = $dbRow.dbid
    $sCmd = $runEnv.sCmd
    $Vstr = $Vstr.ToLower()

    write-verbose "vstr = $Vstr $dbid"
    
    if ($Vstr -eq 'v8') { $type = 'orig' }
    elseif ($Vstr -eq 'v10') { $type = 'conv' }

    $FileStub = $CF_PGMS["run-qc-list-dict-${Vstr}"][1];
    $resFilePFN = "${bStr}_${dbStr}_${FileStub}.txt"
    $resFilePFN =  "$($runEnv.SearchResultsDir)\$resFilePFN"
    write-verbose "Dict-Num: resfile = $resFilePFN"

    # open it first to make sure it's there
    $recs = get-content $resFilePFN
    
    # Update DB
    $statFld = "st_num_dict_${type}"
    $sCmd.CommandText = "UPDATE DCBS SET $statFld=$($recs.length) WHERE batchid=$bid and dbid=$dbid"
    write-verbose "Dict Num: $($sCmd.CommandText)"
    $sCmd.ExecuteNonQuery()
}

function Load-Dict-Query($dbRow, $runEnv, $Vstr) {
    # Calc results file for the v8/10 tag pgms
    $bStr = $runEnv.bStr
    $bid = $runEnv.bid
    $dbid = $dbRow.dbid
    $sCmd = $runEnv.sCmd
    $Vstr = $Vstr.ToLower()

    write-verbose "vstr = $Vstr $dbid"
    
    if ($Vstr -eq 'v8') { $type = 'orig' }
    elseif ($Vstr -eq 'v10') { $type = 'conv' }

    $FileStub = $CF_PGMS["run-qc-query-dict-${Vstr}"][1];
    $resFilePFN = "${bStr}_${dbStr}_${FileStub}.txt"
    $resFilePFN =  "$($runEnv.SearchResultsDir)\$resFilePFN"

    # open it first to make sure it's there
    $recs = get-content $resFilePFN

    # if v8, delete any old recs for this db 
    if ($Vstr -eq 'v8') {
        $t = "DELETE FROM Dict_QC_Words WHERE "
        $t += " batchid=$batchid"
        $t += " AND dbid=$dbid"
        $sCmd.CommandText = $t
        $sCmd.ExecuteNonQuery() > $null
    }

    # format is work numHits numDocs 
    foreach ($rec in $recs) {
        ($srcNum, $numHits, $numDocs, $word) = $rec -split "`t"
        # for $word, strip off surrounding quotes
        #            replace ' with ''
        #            quote it with '
        write-verbose "word x${word}x   numHits $numHits   numDocs $numDocs"
        if ($word -eq "<Entire Database>") { continue }
        $word = $word -replace '"', ''
        $word = $word -replace "'", "''"
        $word = "'$word'" 

        # if v8, insert new recs.  
        # else try to update existing word, else make new rec
        if ($Vstr -eq 'v8') {
            $t = "INSERT INTO Dict_QC_Words (batchid,dbid,word,${type}_hit_cnt,${type}_doc_cnt)"
            $t += " VALUES ($bid, $dbid, $word, $numHits, $numDocs)"
        }
        else {
            $t = "SELECT ID from Dict_QC_Words"
            $t += " WHERE batchid=$bid and dbid=$dbid and word=$word"
            write-verbose "Load: existing word: $t"
            $sCmd.CommandText = $t
            $reader = $sCmd.ExecuteReader()
            if ($reader.read()) { 
                $id = $reader.Item("id")
                $t = "UPDATE Dict_QC_Words SET ${type}_hit_cnt=$numHits , ${type}_doc_cnt=$numDocs"
                $t += " WHERE id=$id"
            }
            else {
                $t = "INSERT INTO Dict_QC_Words (batchid,dbid,word,${type}_hit_cnt,${type}_doc_cnt)"
                $t += " VALUES ($bid, $dbid, $word, $numHits, $numDocs)"
            }
            $reader.close() # should use ExecuteScalar, but not familiar with it
        }
        $sCmd.CommandText = $t
        $sCmd.ExecuteNonQuery() > $null
        write-verbose $t
    }
}

# Populate status_auto field in Dict_QC_Words
function compare-dict-results ($dbRow, $runEnv) {
    $bStr = $runEnv.bStr
    $dbid = $dbRow.dbid
    $sQry = $runEnv.sCmd

    try {
        $sUpd = CF-Get-SQL-Cmd
        $cmd = ""

        $sQry.CommandText = @"
select ID, dbid, word, orig_hit_cnt, orig_doc_cnt, conv_hit_cnt, conv_doc_cnt
FROM Dict_QC_Words WHERE dbid=$dbid
"@
        write-verbose "update stat: qry cmd = `n$($sQry.CommandText)"

        $reader = $sQry.ExecuteReader()
        while ($reader.Read()) {
            $id = $reader.Item('id')
            $word = $reader.Item('word')
            $orig_hit_cnt = $reader.Item('orig_hit_cnt')
            $orig_doc_cnt = $reader.Item('orig_doc_cnt')
            $conv_hit_cnt = $reader.Item('conv_hit_cnt')
            $conv_doc_cnt = $reader.Item('conv_doc_cnt')

            write-verbose "update stat: $word $orig_hit_cnt $orig_doc_cnt  $conv_hit_cnt  $conv_doc_cnt"

            # Calc 'status_auto'
            # Possible values:
            #   U = unchecked
            #   P = Passed
            #   F = Failed
            # The values will frequently not be exactly the same b/c
            # v10 indexes differently.  So how close is close enough?
            # A percentage seems reasonable, but frequently the hit counts are quite low, only 
            # 1 or 2.  Maybe just say as long as v10 is >= v8

            # Keep it as simple as possible for now:
            # Flag as error if cnts don't match
            $stat = 'P'
            if ($orig_hit_cnt -ne $conv_hit_cnt) {
                $stat = 'F'
            }
            if ($orig_doc_cnt -ne $conv_doc_cnt) {
                $stat = 'F'
            }
            # default value for all the cnts is -2,
            # meaning that word wasn't even in the dict
            if (($orig_hit_cnt -eq -2) -or ($orig_doc_cnt -eq -2) -or
                ($conv_hit_cnt -eq -2) -or ($conv_doc_cnt -eq -2)) {
                $stat = 'F'
            }

            # Make eror log entry
            if ($stat -eq 'F') {
                $msg = "|ERROR|Word = $word|Orig cnts: $orig_hit_cnt, $orig_doc_cnt|Conv cnts: $conv_hit_cnt, $conv_doc_cnt"
                CF-Write-Log $resFilePFN $msg $false
                $script:rowResultsHasError = $true
            }
            # I have GOT to learn how to use parameters ;)
            $cmd += @"
UPDATE Dict_QC_Words SET status_auto='$stat' where ID='$id';
"@
        }
        # Save a *little* bit of time by updating all recs for given 
        # dbid at the same time
        write-verbose "update status: cmd = $cmd"
        $sUpd.CommandText = $cmd
        $sUpd.ExecuteNonQuery()
    }
    finally {
        $sUpd.Connection.Close()
    }
}
        
function Process-Row($dbRow, $runEnv) {
    # Inits
    $bStr = $runEnv.bStr
    $dbid = $dbRow.dbid
    $dbStr = "{0:0000}" -f [int]$dbid
    $sCmd = $runEnv.sCmd
    ($script:statusFilePFN, $script:resFilePFN) = CF-Init-RunEnv-This-Row2 $runEnv $dbRow
    echo $null > $script:statusFilePFN
    echo $null > $script:resFilePFN
    $script:rowHasError = $false
    $script:rowResultsHasError = $false

    try {
        Get-Num-Words-In-Dict $dbRow $runEnv "v8"
        Get-Num-Words-In-Dict $dbRow $runEnv "v10"
        Load-Dict-Query $dbRow $runEnv "v8" 
        Load-Dict-Query $dbRow $runEnv "v10"
        compare-dict-results $dbRow $runEnv
    }
    catch {
        CF-Write-Log $script:statusFilePFN "|ERROR|$($error[0])"
        $script:rowHasError = $true
    }
    CF-Finish-Log $script:statusFilePFN 
    CF-Finish-Results-Log $script:resFilePFN
}

function Main {
    # Inits
    $startdate = $(get-date -format $CF_DateFormat)
    $rowsCompared = 0
    $runEnv = CF-Init-RunEnv $BatchID 
    try {
        $runEnv["sCmd"] = CF-Get-SQL-Cmd "FYI_Conversions"
        $dcbRows = CF-Read-DB-File "DCBs" "BatchID" $BatchID

        # Setup start/stop rows (assume user specifies as 1-based)
        if ($startRow -eq $null) { $startRow = 1 }
        if ($endRow -eq $null) { $endRow = $dcbRows.length } 
        CF-Log-To-Master-Log $runEnv.bstr "" "STATUS" "Start row=$startRow  End row=$endRow"
         
        # DCB Rows Loop
        for ($i = ($startRow-1) ; $i -lt $endRow ; $i++) {
            $row = $dcbRows[$i]
            
            $arrPreReqs = @()
            $arrPreReqs += $row.st_qc_query_dict_v8
            $arrPreReqs += $row.st_qc_query_dict_v10
           
            if (CF-Skip-This-Row $runEnv $row $arrPreReqs) {
                continue
            }

            CF-Write-Progress $row.dbid $row.conv_dcb
            Process-Row $row $runEnv 

        }

        CF-Log-To-Master-Log $runEnv.bstr "" "STATUS" "STOP  Start row=$startRow  End row=$endRow"
        $endDate = $(get-date -format $CF_DateFormat)
        write-host "*** Done: batch = $BatchID Start row=$startRow  End row=$endRow"
        write-host "Start: $startDate"
        write-host "End:   $endDate"
    }
    finally {
        $runEnv.sCmd.Connection.close()
    }
}

Main


