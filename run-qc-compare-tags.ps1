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
    [switch] $ignoreStatus,
    $DBId,
    $DriverFile,
    $startRow,
    $endRow
)

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
    CF-Init-RunEnv-This-Row $runEnv $dbRow

    # Inits
    $bStr = $runEnv.bStr
    $dbid = $dbRow.dbid
    $dbStr = "{0:0000}" -f [int]$dbid

    $script:rowHasError = $false
    try {
        # status file for THIS pgm
        $statusFile = "${bStr}_${dbStr}_qc-compare-tags_STATUS.txt"
        $script:statusFilePFN =  "$($runEnv.ProgramLogsDir)\$statusFile"
        echo $null > $script:statusFilePFN

        # results file for THIS pgm
        $resFile = "${bStr}_${dbStr}_qc-compare-tags.txt"
        $resFilePFN =  "$($runEnv.SearchResultsDir)\$resFile"
        echo $null > $resFilePFN

        # Calc results file for the v8/10 tag pgms
        $v8FileStub = $CF_PGMS['run-qc-v8-tags'][1];
        $v8ResFilePFN = "${bStr}_${dbStr}_${v8FileStub}.txt"
        $v8ResFilePFN =  "$($runEnv.SearchResultsDir)\$v8ResFilePFN"

        $v10FileStub = $CF_PGMS['run-qc-v10-tags'][1];
        $v10ResFilePFN = "${bStr}_${dbStr}_${v10FileStub}.txt"
        $v10ResFilePFN =  "$($runEnv.SearchResultsDir)\$v10ResFilePFN"

        compare-tag-files $v8ResFilePFN $v10ResFilePFN $resFilePFN

    }
    catch {
        CF-Write-Log $script:statusFilePFN "|ERROR|$($error[0])"
        $script:rowHasError = $true
    }
    CF-Finish-Log $script:statusFilePFN 
}

function Main {
    $startdate = $(get-date -format $CF_DateFormat)
    $rowsCompared = 0
    $runEnv = CF-Init-RunEnv $BatchID 
    $dcbRows = CF-Read-DB-File "DCBs" "BatchID" $BatchID

    # Setup start/stop rows (assume user specifies as 1-based)
    if ($startRow -eq $null) { $startRow = 1 }
    if ($endRow -eq $null) { $endRow = $dcbRows.length } 
    CF-Log-To-Master-Log $runEnv.bstr "" "STATUS" "Start row=$startRow  End row=$endRow"
     
    # DCB Rows Loop
    for ($i = ($startRow-1) ; $i -lt $endRow ; $i++) {
        $row = $dcbRows[$i]
        
        $arrPreReqs = @($row.st_qc_v8_tags, $row.st_qc_v10_tags)
        if (CF-Skip-This-Row $runEnv $row $arrPreReqs) {
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


