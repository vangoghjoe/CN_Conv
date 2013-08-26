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
    $script:volPaths[$key] = @{}

    $recs = get-content $volPfn
    for ($rec in $recs) {
        # ignore lines that don't look like paths
        if (CF-IsPath $rec) {
            ($path, $key) = $rec -split "\|"
            $script:volPaths[$key] = $path
        }
    }
}

# DIR File like
#QVT00000003	QVT00000003.TIF|-2147483648
#QVT00000004	QVT00000004.TIF|0

function Process-Dir($dirPfn) {

    $recs = get-content $dirPfn
    for ($rec in $recs) {
            ($id, $file, [int]$key) = $rec -split "[\s+\|]"
            if ($key -lt 0) { 
                $key += [math]::Pow(2,31)
            }
            if ($script:volPaths.Contains($key)) {
                CF-Write-Log $script:resFilePFN ("$file" + $script:volPaths[$key])
            }
            else {
                CF-Write-Log $script:logPfn "|ERROR|key $key in DIR doesn't exist in VOL"
                $script:rowHasError = $true
                return
            }
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

    $dcbPfn = $dbRow.conv_dcb;
    
    $dbStr = "{0:0000}" -f [int]$dbid
    $resFile = "${bStr}_${dbStr}_images_ALL.txt"
    $statusFile = "${bStr}_${dbStr}_images_STATUS.txt"
    #$localResFilePFN = "$dcbDir\$CF_LocaldcbDir
    $script:resFilePFN = "$($runEnv.SearchResultsDir)\$resFile"
    $script:statusFilePFN =  "$($runEnv.ProgramLogsDir)\$statusFile"

    Initialize-Log $script:statusFilePFN
    $script:rowHasError = $false
    try {
        if (CheckFiles $dirResFilePFN $volResFilePFN) {
            ProcessVol $volResFilePFN
            ProcessDir $dirResFilePFN
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
            if ((get-item out.csv).length -le 0) { 
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
         
        # going to write to batchResult File
        # status to batchStatus = 1 per DB per pgm
        #  steps table in db can have separate field for step name and pgm-that-does-step
        # if processing breadth first, step name can be ALL STEPS

        for($i = 0 ; $i -lt $dcbRows.length; $i++) {
            $row = $dcbRows[$i]
            
            if ($row.batchid -ne $BatchID) {   
                continue
            }
            Exec-Process-Results $row $runEnv  $CN_EXE 
    }
    catch {
        CF-Log-To-Master-Log $runEnv.bstr "" "ERROR" "$error[0]"
    }

    CF-Log-To-Master-Log $runEnv.bstr "" "STATUS" "STOP"
}     

Main

