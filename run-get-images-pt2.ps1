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

function Initialize-Log ($logPfn) {
   clear-content $script:logPfn
}

# globals needed:  $script:logPfn
function Write-Log ($msg) {
    $msg = "$(get-date -format $CF_DateFormat)|$msg"
    write $msg
}


function Process-Vol($volPfn) {
    
}

# Analyze the results from the CPL that ran in separate process
function Exec-Process-Results {
    param (
        $dbRow,
        $runEnv,
        $CN_EXE,
        $Vstr
    )

    # if we're calling this for v8, still use the "conv" dcb, 
    # b/c at this point in the process is that it hasn't 
    # been converted yet
    $dcbPfn = $dbRow.conv_dcb;
    
    $dbStr = "{0:0000}" -f [int]$dbid
    $dcbDir = [system.io.path]::GetDirectoryName($dcbPfn)
    $dirResFile = "${bStr}_${dbStr}_images_DIR.txt"
    $volResFile = "${bStr}_${dbStr}_images_VOL.txt"
    $statusFile = "${bStr}_${dbStr}_images_STATUS.txt"
    #$localResFilePFN = "$dcbDir\$CF_LocaldcbDir
    $dirResFilePFN = CF-Encode-CPL-Safe-Path "$($runEnv.SearchResultsDir)\$dirResFile"
    $volResFilePFN = CF-Encode-CPL-Safe-Path "$($runEnv.SearchResultsDir)\$volResFile"
    $statusFilePFN =  CF-Encode-CPL-Safe-Path "$($runEnv.ProgramLogsDir)\$statusFile"

    if (CheckFiles($dirResFilePFN, $volResFilePFN) {
        ProcessVol($volResFilePFN)
        ProcessDir($dirResFilePFN)
    }
}

function CheckFiles($dirPfn, $volPfn) {
    foreach ($file in @($dirPfn, $volPfn) {
        if (-not (test-path $file)) {
            return $false
        }
        else {
            try {

            }
            catch {
                
    }
}

function GetFileSize($file) {
    
}
file not there
size not readable

# DIR File like
#QVT00000003	QVT00000003.TIF|-2147483648
#QVT00000004	QVT00000004.TIF|0

# VOL File like
# \\HL105SPRNTAP1F1\HLDATA\002509\000004\QVT_HL_PRODUCTION\QVT0001\IMAGES\001\|0
# \\HL105SPRNTAP1F1\HLDATA\002509\000004\QVT_HL_PRODUCTION\QVT0001\IMAGES\002\|1
# ...
# 0000000000||\\HL105SPRNTAP1F1\HLDATA\002509\000004\QVT_HL_PRODUCTION\QVT0001\IMAGES\001\|0
# 0000000001||\\HL105SPRNTAP1F1\HLDATA\002509\000004\QVT_HL_PRODUCTION\QVT0001\IMAGES\002\|1

# so, 
    

}   

function Main {
    $runEnv = CF-Init-RunEnv $BatchID
    CF-Log-To-Master-Log $runEnv.bstr "" "STATUS" "START"


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
        Exec-Process-Images $row $runEnv  $CN_EXE 
        # take ownership of this row, this step
    }

    CF-Log-To-Master-Log $runEnv.bstr "" "STATUS" "STOP"
}     

Main

