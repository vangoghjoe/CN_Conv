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
    $DBId,
)

set-strictmode -version latest

. ((Split-Path $script:MyInvocation.MyCommand.Path) + "/libConversion.ps1")

function build-tag-table {
    param (
        [string] $tagFile,
        [string] $version,
        $resFilePFN
    )
    $srchnum = ""
    $hits = 0
    $docs = 0
    $tag = ""
    
    $lines = Get-Content $tagFile
    
    $hash = @{}
    foreach ($line in $lines) {
        # first line should be <Entire Database>, 
        # then lines like "»Tagging My tag«"
        # finally, likes  1 or 2 or 3
        # Only care about the Tagging lines, 
        # meaning first char of tag field is a quote
        # TODO: might as well out all but the actual tag name
        $line = $line.ToUpper()
        ($srchNum, $hits, $docs, $tag) = $line.split("`t")
        
        # Only care about the Tagging lines, 
        # meaning first char of tag field is a quote
        if ($tag.substring(0,1) -eq '"') {
            # in v8, default tag is just called Tagging, so change it to same name
            # as in v10
            if ($version -eq "v8" -and ($tag -eq '"»Tagging«"')) {
                $tag = '"»TAGGING DEFAULT TAG«"'
            }
            # in the hash: $tagname = [ [num hits, num docs], searchnumber ]
            $hash[$tag] = @( @($hits,$docs), $srchNum)
        }  
        #$x
            
    }
    return $hash
}

function compare-tables {
    param (
        $tags1,
        $tags2,
        $pass,
        $resFilePFN
    )
    
    # $pass = pass1 means old 2 new
    # $pass = pass2 means new 2 old; in pass2, we don't compare tag values

    if ($pass -eq "pass1") { $desc = "old2new" } else { $desc = "new2old" }

    
    #TODO: rename this variables: 
    # $tag1Name = $tag1Name  $tag1Info = $tags1[$tag1Name]
    foreach ($h in $tags1.GetEnumerator()) {
        if ($tags2.ContainsKey($h.Name)) {
            $val1 = $tags1[$h.Name][0]
            if ($pass -eq "pass1") {
                $searchNum1 = $tags1[$h.Name][1]
                $val2 = $tags2[$h.Name][0]
                $searchNum2 = $tags2[$h.Name][1]
                
                # compare-object arr1 arr2 -syncwindow
                #  => if same, returns null, else returns the different elems
                $diffs = compare-object $val1 $val2 -syncwindow 0
                if ($diffs) {
                    # Start with "||" to match other types of error entries
                    $msg = "||ERROR|DIFF COUNTS ($desc): tag = $($h.name) |"
                    $msg += "$val1 [search $searchNum1]|"
                    $msg += "$val2 [search $searchNum2]"
                    CF-Write-File $resFilePFN $msg
                    $script:rowResultsHasError += 1
                }
            }
        }
        else {
            # tag in 1 but not 2
            
            # Exception: if v8 had the Default tag 
            # (renamed to Tagging Default Tag when building tag table), with no hits
            # it won't be converted to v10,so that's not an error
            if ( ($h.Name -eq '"»Tagging Default tag«"') -and ($pass -eq "pass1") ) {
                $val1 = $tags1[$h.Name][0];
                $hits = $val1[0];
                $docs = $val1[1];
                if (($hits -eq "0" -and $docs -eq "0")) {
                    continue
                }
            }
            
            # Start with "||" to match other types of error entries
            $msg = "||ERROR|FIRST, NOT SECOND ($desc): $($h.Name)"
            CF-Write-File $resFilePFN $msg
            $script:rowResultsHasError += 1
        }
    }
}

function Load-Dict-Query($dbRow, $runEnv, $Vstr) {
    # Calc results file for the v8/10 tag pgms
    $bStr = $runEnv.bStr
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
        $t += "dbid=$dbid"
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

        # if v8, insert new recs.  If not, update existing, matching on Word
        write-verbose "word $word   numHits $numHits   numDocs $numDocs"
        if ($Vstr -eq 'v8') {
            $t = "INSERT INTO Dict_QC_Words (dbid,word,${type}_hit_cnt,${type}_doc_cnt)"
            $t += " VALUES ($dbid, $word, $numHits, $numDocs)"
        }
        else {
            $t = "UPDATE Dict_QC_Words SET ${type}_hit_cnt=$numHits , ${type}_doc_cnt=$numDocs"
            $t += " WHERE dbid=$dbid and word=$word"
        }
        $sCmd.CommandText = $t
        $sCmd.ExecuteNonQuery() > $null
        write-verbose $t
    }
}

function compare-tag-files($oldTagFile, $newTagFile, $resFilePFN) {
    $script:rowResultsHasError = 0
    $oldTags = build-tag-table $oldTagFile "v8" $resFilePFN
    $newTags = build-tag-table $newTagFile "v10" $resFilePFN

    compare-tables $oldTags $newTags "pass1" $resFilePFN
    compare-tables $newTags $oldTags "pass2" $resFilePFN

    CF-Finish-Results-Log $resFilePFN
}

function Process-Row($dbRow, $runEnv) {
    # Inits
    $bStr = $runEnv.bStr
    $dbid = $dbRow.dbid
    $dbStr = "{0:0000}" -f [int]$dbid
    $sCmd = $runEnv.sCmd
    ($script:statusFilePFN, $resFilePFN) = CF-Init-RunEnv-This-Row2 $runEnv $dbRow
    $script:rowHasError = $false

    try {
        Load-Dict-Query $dbRow $runEnv "v8" 
        Load-Dict-Query $dbRow $runEnv "v10"
    }
    catch {
        CF-Write-Log $script:statusFilePFN "|ERROR|$($error[0])"
        $script:rowHasError = $true
    }
    CF-Finish-Log $script:statusFilePFN 
}

function Main {
    # Inits
    $startdate = $(get-date -format $CF_DateFormat)
    $rowsCompared = 0
    $runEnv = CF-Init-RunEnv $BatchID 
    $runEnv["sCmd"] = CF-Get-SQL-Cmd "FYI_Conversions"
    $dcbRows = CF-Read-DB-File "DCBs" "BatchID" $BatchID

    # Setup start/stop rows (assume user specifies as 1-based)
    if ($startRow -eq $null) { $startRow = 1 }
    if ($endRow -eq $null) { $endRow = $dcbRows.length } 
    CF-Log-To-Master-Log $runEnv.bstr "" "STATUS" "Start row=$startRow  End row=$endRow"
     
    # DCB Rows Loop
    for ($i = ($startRow-1) ; $i -lt $endRow ; $i++) {
        $row = $dcbRows[$i]
        
        if ($row.batchid -ne $BatchID) {   
            continue
        }

        $statVal = $row.$($runEnv.StatusField) 

        if ($statVal -ne $CF_STATUS_READY -and 
            ($statVal -ne "") ) {
            continue
        }
  
        if ($row.st_qc_v8_tags -ne $CF_STATUS_GOOD) {
            continue
        }
        if ($row.st_qc_v10_tags -ne $CF_STATUS_GOOD) {
            continue
        }

        write-host "comparing $($row.dbid)"
        Process-Row $row $runEnv 
    }

    CF-Log-To-Master-Log $runEnv.bstr "" "STATUS" "STOP  Start row=$startRow  End row=$endRow"
    $endDate = $(get-date -format $CF_DateFormat)
    write-host "*** Done: batch = $BatchID Start row=$startRow  End row=$endRow"
    write-host "Start: $startDate"
    write-host "End:   $endDate"
}
Main


