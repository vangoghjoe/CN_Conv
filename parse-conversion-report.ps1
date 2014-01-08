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

set-strictmode -version latest
. ((Split-Path $script:MyInvocation.MyCommand.Path) + "/libConversion.ps1")

function logErr ($msg, $recPtr, $qcflag = 1) {
# right now, "log" is a misnomer
# adds the err msg to the global errmsg string,
# adding some formatting
    if ($recPtr -ne "") {
        $msg = "[line $($recPtr+1)] $msg"
    }
    CF-Write-Log $script:resFilePFN $msg
    $script:rowResultsHasError = 1
}
 
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
        throw "Unable to find a conversion report"
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

# Reads until field matches a value
# Returns new recPtr
# Returns -1 if not found
function ConsumeTillTarget($recs, $recPtr,  $targetStr, $fieldNr=0) {
    $numRecs = $recs.length
    try {
        while (1) {
            if ($recPtr -ge $numRecs) {
                return -1
            }
            else {
                if ($recs[$recPtr][$fieldNr] -match $targetStr) {
                    return $recPtr
                } 
            }
            $recPtr++
        }
    }
    catch {
        $a
    }
}        

# Sets $script:CheckFileRecPtr to  new $recPtr or -1 
# if didn't find a "File_Name" section
#
# NB: don't know why, but when try to return $recPtr from CheckFileSecions
# it passing back $error.  So, hack it by using a global pass the val
function CheckFileSections($recs, $recPtr ) {
    $recPtr = ConsumeTillTarget $recs $recPtr "File_Name"
    if ($recPtr -eq -1) { 
        $script:CheckFileRecPtr = -1
        return
    }
    $recPtr++
    
    $numRecs = $recs.length
    while ($recPtr -lt $numRecs) {
        $fileName = $recs[$recPtr][0]
        $recsBefore = $recs[$recPtr][1]
        $recsAfter = $recs[$recPtr][2]
        $errorRefs = $recs[$recPtr][3]
        # elem 4 is "Notes" which is unused
        $AdminLogin = $recs[$recPtr][5]
        $SecurityEnabled = $recs[$recPtr][6]
        $LogonRequired = $recs[$recPtr][7]

        # End of section
        if ($fileName -eq "") { 
            break
        }

        # Check Before and After agree, unless either of them is marked N/A
        if (($recsBefore -NotMatch "n/a") -and ($recsAfter -NotMatch "n/a")) {
            if ($recsBefore -ne $recsAfter) {
                logErr "||Error|Before and after don't agree: [file = $fileName]: before=$recsBefore  after=$recsAfter" $recPtr;
            }
        }

        if ($ErrorRefs -ne "Error_Refs" -and (-not ($ErrorRefs -match "^\s*$"))) {        
            logErr "||Error|Non-blank ErrorRef: [file = $fileName]: $ErrorRefs" $recPtr;
        }

        if ($AdminLogin -ne "") { 
            logErr "||Error|AdminLogon not blank: [file=$fileName]: $AdminLogin" $recPtr
        }

        if ($SecurityEnabled -ne "No") { 
            logErr "||Error|Security Enabled not 'No': [file=$fileName]: $SecurityEnabled" $recPtr
        }

        if ($LogonRequired -ne "No") { 
            logErr "||Error|Logon Required not 'No': [file=$fileName]: $LogonRequired" $recPtr
        }

        $recPtr++
    }
    # this was returning $error
    #return $recPtr
    $script:CheckFileRecPtr = $recPtr
}

function Parse-Conversion-Report ($reportPFN) {
    
    # the file is TAB delimited, double-quotes around most fields
    # split each line into columns, making $recs an array of array of columns
    # strip out the double-quotes

    # capture all errors into the log
    try {
        CF-Write-Log $script:StatusFilePFN "Conversion Report = '$reportPFN'"
        
        $recs = Get-Content $reportPFN | 
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
        # Docs before/after
        $recPtr = ConsumeTillTarget $recs $recPtr "Documents before conversion:"
        if ($recPtr -eq -1) { throw "Can't find line: 'Documents before conversion" }
        $docsBefore = $recs[$recPtr][1]
        $docsAfter = $recs[$recPtr+1][1]

        if ($docsBefore -ne $docsAfter) {
            logErr "Mismatched doc numbers: before = $docsBefore - after = $docsAfter" $recPtr
        }

        ###   File_Name Sections
        # Must be at least one, and up to three
        # One each for Main, Notes and Redlines
        # 

        for ($i=1; $i -le 3; $i++) {
            CheckFileSections $recs $recPtr
            $recPtr = $script:CheckFileRecPtr
            if ($recPtr -eq -1) { break }
        }
        if ($i -eq 1) {
            logErr "No 'File_Name' sections found"
        }
        
        # "Errors that occured during processing"
        # Have to start over at 0 after the FileName sections b/c
        # we don't know how FileName sections there are
        $recPtr = 0
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
        
    } # end try
    catch {
        # all exceptions and errors will go into progam status file
        # QC errors will say QC ERROR at beginning
        CF-Write-Log $script:statusFilePFN "|ERROR|$($error[0])"
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
    $script:rowResultsHasError = $false
    try {
        # status file for THIS pgm
        $statusFile = "${bStr}_${dbStr}_qc-conv-report_STATUS.txt"
        $script:statusFilePFN =  "$($runEnv.ProgramLogsDir)\$statusFile"
        echo $null > $script:statusFilePFN

        # results file for THIS pgm
        $resFile = "${bStr}_${dbStr}_qc-conv-report.txt"
        $script:resFilePFN =  "$($runEnv.SearchResultsDir)\$resFile"
        echo $null > $resFilePFN

        $reportPFN = DCB-To-CR $row.conv_dcb
        Parse-Conversion-Report $reportPFN

    }
    catch {
        CF-Write-Log $script:statusFilePFN "|ERROR|$($error[0])"
        $script:rowHasError = $true
    }
    finally {
        CF-Finish-Log $script:StatusFilePFN
        CF-Finish-Results-Log $script:resFilePFN
    }
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
        
        $arrPreReqs = @($row.st_convert_one_dcb)
        if (CF-Skip-This-Row $runEnv $row $arrPreReqs) {
            continue
        }
        Process-Row $row $runEnv 
    }

    CF-Log-To-Master-Log $runEnv.bstr "" "STATUS" "STOP  Start row=$startRow  End row=$endRow"
    $endDate = $(get-date -format $CF_DateFormat)
    write-host "*** Done: batch = $BatchID Start row=$startRow  End row=$endRow"
    write-host "Start: $startDate"
    write-host "End:   $endDate"
}
Main


