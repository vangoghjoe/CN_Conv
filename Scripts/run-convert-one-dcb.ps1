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
param([string] $BatchID)

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
      
    
function Exec-CPL ($dbRow, $runEnv, $CN_EXE) {

    $bStr = $runEnv.bStr
    
    $dbid = $dbRow.dbid

    # if we're calling this for v8, still use the "conv" dcb, 
    # b/c at this point in the process is that it hasn't 
    # been converted yet

    try {
        $dcbPfn = $dbRow.conv_dcb;
        
        $dbStr = "{0:0000}" -f [int]$dbid
        $dcbDir = [system.io.path]::GetDirectoryName($dcbPfn)
        $statusFile = "${bStr}_${dbStr}_${VStr}_convert_one_dcb_STATUS.txt"

        $statusFilePFN =  CF-Encode-CPL-Safe-Path "$($runEnv.ProgramLogsDir)\$statusFile"
        
        $safeDcbPfn = CF-Encode-CPL-Safe-Path $dcbPfn
        $myargs = @("/nosplash", $CPT, $safeDcbPfn, $statusFilePFN)
        CF-Log-To-Master-Log $bStr $dbStr "STATUS" "Start dcb: $dcbPfn"

        $proc = (start-process $CN_EXE -ArgumentList $myargs -Wait -NoNewWindow -PassThru)
        if ($proc.ExitCode -gt 1) {
            CF-Log-To-Master-Log $bStr $dbStr "ERROR" "Bad exitcode CPL: $dcbPfn"
            # log special error to Master Log
        }
        CF-Log-To-Master-Log $bStr $dbStr "STATUS" "Finish dcb: $dcbPfn"
    
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

