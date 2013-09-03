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
    $CN_Ver
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

    $recs = get-content $volPfn
    foreach ($rec in $recs) {
        # ignore lines that don't look like paths

        $rec = $rec.Trim()
        if (CF-IsPath $rec) {
            ($path, [int]$key) = $rec -split "\|"
            
            $path = $path.Trim()        
            $script:volPaths[$key] = $path
        }
    }
}

# DIR File like
#QVT00000003	QVT00000003.TIF|-2147483648
#QVT00000004	QVT00000004.TIF|0

function Process-Dir($dirPfn) {

    $recs = get-content $dirPfn
    foreach ($rec in $recs) {
        ($id, $file, [int]$key) = $rec -split "[\s+\|]"
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
        $runEnv,
        $CN_EXE,
        $Vstr
    )

    $bStr = $runEnv.bStr
    $dbid = $dbRow.dbid
    
    $dcbPfn = $dbRow.conv_dcb;
    
    $dbStr = "{0:0000}" -f [int]$dbid
    $resFile = "${bStr}_${dbStr}_images_ALL.txt"
    $dirResFile = "${bStr}_${dbStr}_images_DIR.txt"
    $volResFile = "${bStr}_${dbStr}_images_VOL.txt"
    $statusFile = "${bStr}_${dbStr}_images_pt2_STATUS.txt"
    #$localResFilePFN = "$dcbDir\$CF_LocaldcbDir
    $dirResFilePFN = "$($runEnv.SearchResultsDir)\$dirResFile"
    $volResFilePFN = "$($runEnv.SearchResultsDir)\$volResFile"
    $script:resFilePFN = "$($runEnv.SearchResultsDir)\$resFile"
    $script:statusFilePFN =  "$($runEnv.ProgramLogsDir)\$statusFile"

    write-host $script:statusFilePFN

    CF-Initialize-Log $script:statusFilePFN
    CF-Initialize-Log $script:resFilePFN 
    
    $script:rowHasError = $false
    try {
        if (CheckFiles $dirResFilePFN $volResFilePFN) {
            Process-Vol $volResFilePFN
            Process-Dir $dirResFilePFN
        }
    }
    catch {
        CF-Write-Log $script:statusFilePFN "|ERROR|$error[0]"
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
    $runEnv = CF-Init-RunEnv $BatchID
    CF-Log-To-Master-Log $runEnv.bstr "" "STATUS" "START"

    try {

        $dcbRows = CF-Read-DB-File "DCBs" "BatchID" $BatchID
         
        # Load driver file, if using
        if ($DriverFile) {
            CF-Load-Driver-File $DriverFile
        }

        # going to write to batchResult File
        # status to batchStatus = 1 per DB per pgm
        #  steps table in db can have separate field for step name and pgm-that-does-step
        # if processing breadth first, step name can be ALL STEPS

        for($i = 0 ; $i -lt $dcbRows.length; $i++) {
            $row = $dcbRows[$i]
            
            if ($row.batchid -ne $BatchID) {   
                continue
            }

            # Check against driver file, if using
            if ($DriverFile) {
                write-host "in driver check: $($row.dbid)"
                if (-not (CF-Is-DBID-in-Driver $row.dbid)) {
                    write-host "not in driver: $($row.dbid)"
                    continue
                }
                write-host "in driver: $($row.dbid)"
            }
            Exec-Process-Results $row $runEnv  $CN_EXE 
        }
    }
    catch {
        write-host $error[0]
        CF-Log-To-Master-Log $runEnv.bstr "" "ERROR" "$error[0]"
    }

    CF-Log-To-Master-Log $runEnv.bstr "" "STATUS" "STOP"
}     

Main

