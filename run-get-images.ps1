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
    $CPT_name = "hogan-get-image-files_${Vstr}.CPT"
    
    if ($(hostname) -eq "LNGHBEL-5009970") {
        $CPT_DEV_DIR = "C:\Documents and Settings\hudsonj1\My Documents\Hogan\Scripts\CPLs\"
        $CPT = "C:\Conversions\CPLs\$CPT_name"
        copy-item -Force "$CPT_DEV_DIR\$CPT_name" "$CPT"
    }
    else {
        $CPT = "$CF_ScriptDir\CPLs\$CPT_name"
    }

    # make sure CPT doesn't have whitespace
    if ($CPT -match "\s") {
        write-host "FATAL ERROR: .cpt path cannot contain whitespace: $CPT"
    }
    $script:CPT = $CPT
}

# This runs the CPL that simply lists the contents of the DIR and VOL files
# Another function will have to analyze those files to get the actual image paths
function Exec-Process-Images {
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

    # Set up file names
    $dirResFile = "${bStr}_${dbStr}_images_DIR.txt"
    $dirResFile = CF-Encode-CPL-Safe-Path "$($runEnv.SearchResultsDir)\$dirResFile"
    $volResFile = "${bStr}_${dbStr}_images_VOL.txt"
    $volResFile = CF-Encode-CPL-Safe-Path "$($runEnv.SearchResultsDir)\$volResFile"
    $statusFile = "${bStr}_${dbStr}_images_STATUS.txt"
    $statusFile =  CF-Encode-CPL-Safe-Path "$($runEnv.ProgramLogsDir)\$statusFile"
    $safeDcbPfn = CF-Encode-CPL-Safe-Path $dcbPfn

    $myargs = @("/nosplash", $CPT, $safeDcbPfn, $dirResFile, $volResFile, $statusFile)
    CF-Log-To-Master-Log $bStr $dbStr "STATUS" "Start dcb: $dcbPfn"
    $myargs
    write ""
    $proc = (start-process $CN_EXE -ArgumentList $myargs -Wait -NoNewWindow -PassThru)
    if ($proc.ExitCode -gt 1) {
        CF-Log-To-Master-Log $bStr $dbStr "ERROR" "Bad exitcode CPL: $dcbPfn"
        # log special error to Master Log
    }

    # Kludge warning: 
    # If pgm indicates success, put an empty results file if not
    # already there
    $statusFile = CF-Decode-CPL-Safe-Path $statusFile
    $dirResFile = CF-Decode-CPL-Safe-Path $dirResFile
    $volResFile = CF-Decode-CPL-Safe-Path $volResFile
    if (CF-Log-Says-Ran-Successfully $statusFile) {
        foreach ($file in @($dirResFile, $volResFile)) {
            if (-not (test-path $file)) {
                echo $null > $file
            }
        }
    }
    CF-Log-To-Master-Log $bStr $dbStr "STATUS" "Finish dcb: $dcbPfn"

}   

function Main {
    # Inits
    $runEnv = CF-Init-RunEnv $BatchID
    CF-Log-To-Master-Log $runEnv.bstr "" "START" ""

    try {
        $startDate = $(get-date -format $CF_DateFormat)
        ($Vstr, $script:CN_EXE) = CF-Get-CN-Info $CN_Ver 
        Set-Up-CPT $Vstr

        $dcbRows = CF-Read-DB-File "DCBs" "BatchID" $BatchID

        # Load driver file, if using
        if ($DriverFile) {
            CF-Load-Driver-File $DriverFile
        }
         
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
            Exec-Process-Images $row $runEnv  $CN_EXE 
        }
    }
    catch {
        write-host $error[0]
        CF-Log-To-Master-Log $runEnv.bstr "" "ERROR" "$($error[0])"
    }

    # Wrap up
    CF-Log-To-Master-Log $runEnv.bstr "" "STATUS" "STOP CN=$Vstr Start row=$startRow  End row=$endRow"
    $endDate = $(get-date -format $CF_DateFormat)
    write-host "*** Done: batch = $BatchID CN=$Vstr Start row=$startRow  End row=$endRow"
    write-host "Start: $startDate"
    write-host "End:   $endDate"
    if (-not $DriverFile ) { $DriverFile = "None" }
    write-host "Driver file = $DriverFile"
}     

Main
