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
    $DriverFile,
    $startRow,
    $endRow
)


. ((Split-Path $script:MyInvocation.MyCommand.Path) + "/libConversion.ps1")

# VOL File like
# \\HL105SPRNTAP1F1\HLDATA\002509\000004\QVT_HL_PRODUCTION\QVT0001\IMAGES\001\|0
# \\HL105SPRNTAP1F1\HLDATA\002509\000004\QVT_HL_PRODUCTION\QVT0001\IMAGES\002\|1
# ...
# 0000000000||\\HL105SPRNTAP1F1\HLDATA\002509\000004\QVT_HL_PRODUCTION\QVT0001\IMAGES\001\|0
# 0000000001||\\HL105SPRNTAP1F1\HLDATA\002509\000004\QVT_HL_PRODUCTION\QVT0001\IMAGES\002\|1

function Process-Vol($volPfn) {

    # would be faster with arrays, but don't have time to fuss with it
    $script:volPaths = @{}

    # Force array context in case file only has one line
    $recs = @(get-content $volPfn)  # need this to work if file only has one line
    foreach ($rec in $recs) {

        $rec = $rec.Trim()
        # ignore lines that don't look like paths
        if (CF-IsPath $rec) {
            ($path, [int]$key) = $rec -split "\|"
            #write-host "proc-vol: path: $path  key: $key" #debug
            $path = $path.Trim()        
            $script:volPaths[$key] = $path
        }
    }
}

# DIR File like
#QVT00000003	QVT00000003.TIF|-2147483648
#QVT00000004	QVT00000004.TIF|0

function Process-Dir($dirPfn) {

    # Force array context in case file only has one line
    $recs = @(get-content $dirPfn) 
    foreach ($rec in $recs) {
        #($id, $file, [int]$key) = $rec -split "[\s+\|]"
        ($id, $file, [int]$key) = $rec -split "[\t\|]"
        $file = $file.trim()
        # debug
        #write-host "proc-dir: file: $file  key: $key"
        if ($key -lt 0) { 
            $key += [math]::Pow(2,31)
        }
        if ($script:volPaths.Contains($key)) {
             ($script:volPaths[$key]+$file) | out-file -Encoding ASCII -append -filepath $script:resFilePFN 
        }
        else {
            CF-Write-Log $script:logPfn "|ERROR|key $key in DIR doesn't exist in VOL"
            $script:rowHasError = $true
            return
        }
    }
}

# Analyze the results from the CPL that ran in separate process
function Exec-Process-Results {
    param (
        $dbRow,
        $runEnv
    )

    $bStr = $runEnv.bStr
    $dbid = $dbRow.dbid
    
    $dcbPfn = $dbRow.conv_dcb;
    
    $dbStr = "{0:0000}" -f [int]$dbid
    $resFile = "${bStr}_${dbStr}_images_ALL.txt"
    $dirResFile = "${bStr}_${dbStr}_images_DIR.txt"
    $volResFile = "${bStr}_${dbStr}_images_VOL.txt"
    $statusFile = "${bStr}_${dbStr}_images_pt2_STATUS.txt"

    #debug
    #write-host "status file without path = $statusFile"

    #$localResFilePFN = "$dcbDir\$CF_LocaldcbDir
    $dirResFilePFN = "$($runEnv.SearchResultsDir)\$dirResFile"
    $volResFilePFN = "$($runEnv.SearchResultsDir)\$volResFile"
    $script:resFilePFN = "$($runEnv.SearchResultsDir)\$resFile"
    $script:statusFilePFN =  "$($runEnv.ProgramLogsDir)\$statusFile"

    # debug
    #write-host "pgm logs = $($runEnv.ProgramLogsDir)"
    write-host $script:statusFilePFN

    CF-Initialize-Log $script:statusFilePFN
    CF-Initialize-Log $script:resFilePFN 
    
    $script:rowHasError = $false
    try {
        if (CheckFiles $dirResFilePFN $volResFilePFN) {
            Process-Vol $volResFilePFN
            Process-Dir $dirResFilePFN
        }
        else {
            # decided it should be an error to be asked to run when don't 
            # have correct input files.
            CF-Write-Log $script:statusFilePFN "|ERROR|The input VOL and/or DIR are missing."
            $script:rowHasError = $true

        }
    }
    catch {
        CF-Write-Log $script:statusFilePFN "|ERROR|$($error[0])"
        $script:rowHasError = $true
    }
    CF-Finish-Log $script:statusFilePFN 
}

# To return true, need every file to both exist and be non-zero
function CheckFiles($dirPfn, $volPfn) {
    foreach ($file in @($dirPfn, $volPfn)) {
        if (-not (test-path $file)) {
            return $false
        }
        else {
            $len = (get-item $file).length
            if ($len -le 0) { 
                return $false 
            }
        }
    }
    return $true
}


function Main {
    # Bare inits to write to master log
    $runEnv = CF-Init-RunEnv $BatchID
    CF-Log-To-Master-Log $runEnv.bstr "" "START" ""

    try {
        # Inits
        $startDate = $(get-date -format $CF_DateFormat)
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
            Exec-Process-Results $row $runEnv 
        }
    }
    catch {
        write-host $error[0]
        CF-Log-To-Master-Log $runEnv.bstr "" "ERROR" "$($error[0])"
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

