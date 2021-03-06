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

param(
    $BatchID,
    $DriverFile,
    $startRow,
    $endRow,
    $CN_Ver = "v8"
)


. ((Split-Path $script:MyInvocation.MyCommand.Path) + "/libConversion.ps1")


function Set-Up-CPT ($Vstr) {
    $CPT_name = "hogan-get-native-files_${Vstr}.CPT"
    
    if ($(hostname) -eq "LNGHBEL-5009970") {
        $CPT_DEV_DIR = "C:\Documents and Settings\hudsonj1\My Documents\Hogan\Scripts\CPLs\"
        $CPT = "C:\Conversions\CPLs\$CPT_name"
        copy-item -Force "$CPT_DEV_DIR\$CPT_name" "$CPT"
    }
    else {
        $CPT = "$CF_ScriptDir\CPLs\$CPT_name"
    }

    if (-not (test-path $CPT)) {
        throw "Can't find CPT: $CPT"
    }

    # make sure CPT doesn't have whitespace
    if ($CPT -match "\s") {
        write-host "FATAL ERROR: .cpt path cannot contain whitespace: $CPT"
    }
    $script:CPT = $CPT
}

function Process-Row {
    param (
        $dbRow,
        $runEnv,
        $CN_EXE,
        $Vstr
    )
    $bStr = $runEnv.bStr
    
    $dbid = $dbRow.dbid

    # if we're calling this for v8, still use the "conv" dcb, 
    # b/c at this point in the process is that it hasn't 
    # been converted yet
    $dcbPfn = $dbRow.conv_dcb;
    
    $dbStr = "{0:0000}" -f [int]$dbid
    $dcbDir = [system.io.path]::GetDirectoryName($dcbPfn)
    $resFile = "${bStr}_${dbStr}_natives.txt"
    $resFilePFN =  "$($runEnv.SearchResultsDir)\$resFile"
    $resFilePFNSafe = CF-Encode-CPL-Safe-Path $resFilePFN
    $statusFile = "${bStr}_${dbStr}_natives_STATUS.txt"
    $statusFilePFN =  "$($runEnv.ProgramLogsDir)\$statusFile"
    $statusFilePFNSafe =  CF-Encode-CPL-Safe-Path $statusFilePFN
    
    $safeDcbPfn = CF-Encode-CPL-Safe-Path $dcbPfn
    $myargs = @("/nosplash", $CPT, $safeDcbPfn, $resFilePFNSafe, $statusFilePFNSafe)
    CF-Log-To-Master-Log $bStr $dbStr "STATUS" "Start dcb: $dcbPfn"

    # Show progress
    get-date
    $myargs
    write ""

    $proc = (start-process $CN_EXE -ArgumentList $myargs -Wait -NoNewWindow -PassThru)
    if ($proc.ExitCode -gt 1) {
        CF-Log-To-Master-Log $bStr $dbStr "ERROR" "Bad exitcode CPL: $dcbPfn"
        # log special error to Master Log
    }

    # Kludge warning: 
    # If pgm indicates success, put an empty results file if 
    # already there
    #rm $resFilePFN > $null # DEBUG DEBUG!!!
    if (CF-Log-Says-Ran-Successfully $statusFilePFN) {
        if (-not (test-path $resFilePFN)) {
            echo $null > $resFilePFN
        }
    }
    CF-Log-To-Master-Log $bStr $dbStr "STATUS" "Finish dcb: $dcbPfn"

}   

function Main {
    $runEnv = CF-Init-RunEnv $BatchID
    CF-Log-To-Master-Log $runEnv.bstr "" "START" "Start row=$startRow  End row=$endRow"
    $startDate = $(get-date -format $CF_DateFormat)

    ($Vstr, $script:CN_EXE) = CF-Get-CN-Info $CN_Ver 
    Set-Up-CPT $Vstr


    # Load driver file, if using
    if ($DriverFile) {
        CF-Load-Driver-File $DriverFile
    }

    $dcbRows = CF-Read-DB-File "DCBs" "BatchID" $BatchID

    # Setup start/stop rows (assume user specifies as 1-based)
    if ($startRow -eq $null) { $startRow = 1 }
    if ($endRow -eq $null) { $endRow = $dcbRows.length } 
    CF-Log-To-Master-Log $runEnv.bstr "" "STATUS" "Start CN=$Vstr row=$startRow  End row=$endRow"
     
    # DCB Rows Loop
    for ($i = ($startRow-1) ; $i -lt $endRow ; $i++) {
        $row = $dcbRows[$i]
        
        if ($row.batchid -ne $BatchID) {   
            continue
        }

        # Check against driver file, if using
        if ($DriverFile) {
            if (-not (CF-Is-DBID-in-Driver $row.dbid)) {
                continue
            }
        }

        Process-Row $row $runEnv $CN_EXE $Vstr 
    }

    # Wrap up
    CF-Log-To-Master-Log $runEnv.bstr "" "STATUS" "STOP Start row=$startRow  End row=$endRow"
    $endDate = $(get-date -format $CF_DateFormat)
    write-host "*** Done: batch = $BatchID Start row=$startRow  End row=$endRow"
    write-host "Start: $startDate"
    write-host "End:   $endDate"
    if (-not $DriverFile ) { $DriverFile = "None" }
    write-host "Driver file = $DriverFile"
}     

Main
