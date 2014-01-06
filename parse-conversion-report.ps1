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
    $startRow,
    $endRow
)

. ((Split-Path $script:MyInvocation.MyCommand.Path) + "/libConversion.ps1")
 
# Given a DCB path, find the Conversion report
# Conversion report names are like
# Conversion Report - $DBNAME - YYYY-MM-DD.csv
# Could be several, so get the latest based on the date in the name
# ie, sort by name and use the highest
function DCB-To-CR ($dcbPfn) {
    $dir = [system.io.path]::GetDirectoryName($dcbPfn)
    $dcbName = [system.io.path]::GetFileNameWithoutExtension($dcbPfn)
    $convRoot = "$dir/Conversion Report - $dcbName"
    try {
        # careful: if only one file, returns a FileInfo object
        #    if > 1, returns an array of FileInfo Objects
        $a = $(Get-ChildItem ${convRoot}* | sort-object -property fullname -Descending)
        if ($a.gettype() -eq "Object[]") {        
            return $a[0]
        }
        else {
            return $a
        }
    }
    catch {
        write "Unable to find a conversion report"
    }
}

# reads until hits a blank line
# changes the value of linect
# throws an error when gets past the end
function ConsumeBlankrecs($recs, $recPtr) {
    $numrecs = $recs.length
    while (1) {
        if ($recPtr -ge $numrecs) {
            return $false
        }
        else {
            # join all the columns into one string and remove any spaces or quotes
            $smush = $recs[$recPtr] -join ""
            # 
            $smush = $smush -replace '["\s]', ""
            if ($smush -eq "") {
                return $true
            }
        }
        $recPtr++
    }
}


# reads until field matches a value
# returns new recPtr
# throws an error if falls off the end of the record
function ConsumeTillTarget($recs, $recPtr,  $targetStr, $fieldNr=0) {
    $numRecs = $recs.length
    while (1) {
        if ($recPtr -ge $numRecs) {
            throw "Reached end of file before finding '$targetStr'"
        }
        else {
            if ($recs[$recPtr][$fieldNr] -match $targetStr) {
                return $recPtr
            } 
        }
        $recPtr++
    }
}        
    
function Parse-Conversion-Report ($reportPFN) {
    
    # the file is TAB delimited, double-quotes around most fields
    # split each line into columns, making $recs an array of array of columns
    # strip out the double-quotes

    # capture all errors into the log
    try {
        Write-Log "Conversion Report = '$reportPFN'"
        
        $recs = Get-Content $convReport | 
                  foreach { $_ -replace '"', '' } |  
                  foreach { , $( $_ -split "`t" ) }
        $numRecs = $recs.length
        
        # let's try totally simple first
        # docs before/after look to be on lines 8 and 9
        # column 4 should be either blank or have the column title "Error_Refs".  Otherwise it's an error
        # Security_Enabled = col 7; should be blank or title or No
        # Logon_Required = col 9; same thing
        # the line after "Errors that occurred during processing:" should blank
        # 

        $recPtr = 0
        #docs before/after
        $recPtr = ConsumeTillTarget $recs $recPtr "Documents before conversion:"
        $docsBefore = $recs[$recPtr][1]
        $docsAfter = $recs[$recPtr+1][1]

        if ($docsBefore -ne $docsAfter) {
            logErr "Mismatched doc numbers: before = $docsBefore - after = $docsAfter" $recPtr
        }
        
        # "Errors that occured during processing"
        $recPtr = ConsumeTillTarget $recs $recPtr "Errors that occured during processing:"
        $recPtr++
        while ($recPtr -lt $numRecs) {
            # if no errors, would only expcect to see blank lines
            # or the line that says "Error codes from 201 to 400 are internal application errors."
            
            # join the array of columns into one big line to see if blank
            # (might be able to do this by using Contains with an array)
            $smush = $recs[$recPtr] -join " "
            
            if (
                (-not ($smush -match "^\s*$")) -and 
                (-not ($smush -match "Error codes from 201 to 400 are internal application errors."))
                ) {
                
                # if it's the last line and it consists of this funny char, ignore it
                if (-not (($recPtr -eq $numRecs-1) -and ($smush -match "¿"))) {            
                    # looks like something suspsicious was reported
                    logErr "Errors during processing: $smush" $recPtr
                }
            }
            
            $recPtr++
        }
        
        # Check stats on each file
        # look for errors in col D (3) 
        # TODO:  check for  Security issues in Admin or Security Enabled
        $recPtr = 0
        $recPtr = ConsumeTillTarget $recs $recPtr "File_Name"
        while ($recPtr -lt $numRecs) {
            $fileName = $recs[$recPtr][0]
            $recsBefore = $recs[$recPtr][1]
            $recsAfter = $recs[$recPtr][2]
            $errorRefs = $recs[$recPtr][3]
            $AdminLogin = $recs[$recPtr][5]
            $SecurityEnabled = $recs[$recPtr][6]
            $LogonRequired = $recs[$recPtr][7]

            if ($ErrorRefs -ne "Error_Refs" -and (-not ($ErrorRefs -match "^\s*$"))) {        
                $msg = "||Error|Non-blank ErrorRef: [file = $fileName]: $ErrorRefs" $recPtr;
                    CF-Write-File $resFilePFN $msg
            }

            # Check Before and After agree, unless either of them is marked N/A
            if (!(($recsBefore -eq "n/a") -or ($recsAfter -eq "n/a"))) {
                if ($recsBefore -ne $recsAfter) {
                    logErr "Non-blank ErrorRef: [file = $file]: $ErrorRefs" $recPtr;
                }
            }
            # later will do something with the security enabled flags

            $recPtr++
            
        }
    } # end try
    catch {
        # all exceptions and errors will go into progam status file
        # QC errors will say QC ERROR at beginning
       $script:errMsg += "`nERROR: " + $error[0] + $error[1]
    }
    finally {
        # write finish to pgm status
        if ($script:errMsg -eq "") {
            write-log "|EXIT STATUS|OK"
        }
        else {
            write-log $script:errMsg
            write-log "|EXIT STATUS|ERROR"
        }
    }
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


