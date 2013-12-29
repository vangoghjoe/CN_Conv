<#
.SYNOPSIS 

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

# local 7/9 1:30P
param([string] $BatchID, $DcbFullName)

. ((Split-Path $script:MyInvocation.MyCommand.Path) + "/libConversion.ps1")


<#
Just thinking, what do we need from this?
* capture any errors after row that says: "Errors that occured during processing:"
* capture any errors in the 'Error_Refs' column (D).  Haven't seen any,  though, so not sure what to look for.  Anything that's not blank, I guess
* Can make a copy of this into the DB _LN-Conversion dir.
* One idea is to add all of ours logging onto the end of this automatic Conversion report.
* 
* need exec status
* qc status = any qc issues

* notify if Security enabled or Logon_required

* maybe several rounds of dev on this
* * just report any errors in the error or columns or at the bottom

* Several parts
* * The header recs, like db name and path
* * Sub db recs, one for each sub-db (main, notes and redlines)
* * * one line for each important file
* * * one line for tag name count
* * * one line for tag to doc.count

* inputs
* * ConvReportPFN
* * Status

* 

#>

# might be a good use of a closure here, but oh well
# globals used: $script:logPfn
function Initialize-Log ($logPfn) {
   clear-content $script:logPfn
}

# globals needed:  $script:logPfn
function Write-Log ($msg) {
    $msg = "$(get-date -format $CF_DateFormat)|$msg"
    write $msg
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
        
        # look for errors in col D (3) 
        # TODO:  check for  Security issues in Admin or Security Enabled
        $recPtr = 0
        while ($recPtr -lt $numRecs) {
            $fileName = $recs[$recPtr][0]
            $recsBefore = $recs[$recPtr][1]
            $recsAfter = $recs[$recPtr][2]
            $errorRefs = $recs[$recPtr][3]
            $AdminLogin = $recs[$recPtr][5]
            $SecurityEnabled = $recs[$recPtr][6]
            $LogonRequired = $recs[$recPtr][7]

            if ($ErrorRefs -ne "Error_Refs" -and (-not ($ErrorRefs -match "^\s*$"))) {        
                logErr "Non-blank ErrorRef: [file = $file]: $ErrorRefs" $recPtr;
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

function logErr ($msg, $recPtr, $qcflag = 1) {
# right now, "log" is a misnomer
# adds the err msg to the global errmsg string,
# adding some formatting

    if ($recPtr -ne "") {
        $msg = "[$recPtr] $msg"
    }

    if ($qcflag) {
        $msg = "QC ERROR: $msg"
    }
    $msg = "$msg`n"

    if ($script:errMsg -eq "") {
        $script:errMsg = "$msg"
    }
    else {
        $script:errMsg += "$msg"
    }
}


function Main {
    try {
    
        # Initialize
        $runEnv = CF-Init-RunEnv $BatchID
        CF-Log-To-Master-Log $runEnv.$bStr "" "STATUS" "START"

        $script:errMsg = "";
        $bStr = $runEnv.bStr        

        $dcbRows = CF-Read-DB-File "DCBs" "BatchID" $bID
      
        foreach ($row in $dcbRows) {

            if ($row.batchid -ne $BatchID) {   
                continue
            }

            Parse-Conversion-Report $row
        }
        
    }
    
    # catch anything, from wherever
    catch {
        write "Error: $error[0]"
    }
}

Main
