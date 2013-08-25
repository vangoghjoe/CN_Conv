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
    $CN_Ver
)


. ((Split-Path $script:MyInvocation.MyCommand.Path) + "/libConversion.ps1")


function Set-Up-CPT ($Vstr) {
    $CPT_name = "hogan-get-image-files.CPT"
    
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
    $dirResFile = "${bStr}_${dbStr}_images_DIR.txt"
    $volResFile = "${bStr}_${dbStr}_images_VOL.txt"
    $statusFile = "${bStr}_${dbStr}_images_STATUS.txt"
    #$localResFilePFN = "$dcbDir\$CF_LocaldcbDir
    $dirResFilePFN = CF-Encode-CPL-Safe-Path "$($runEnv.SearchResultsDir)\$dirResFile"
    $volResFilePFN = CF-Encode-CPL-Safe-Path "$($runEnv.SearchResultsDir)\$volResFile"
    $statusFilePFN =  CF-Encode-CPL-Safe-Path "$($runEnv.ProgramLogsDir)\$statusFile"
    
    $safeDcbPfn = CF-Encode-CPL-Safe-Path $dcbPfn
    $myargs = @("/nosplash", $CPT, $safeDcbPfn, $dirResFilePFN, $volResFilePFN, $statusFilePFN)
    CF-Log-To-Master-Log $bStr $dbStr "STATUS" "Start dcb: $dcbPfn"
    $myargs
    write ""
    $proc = (start-process $CN_EXE -ArgumentList $myargs -Wait -NoNewWindow -PassThru)
    if ($proc.ExitCode -gt 1) {
        CF-Log-To-Master-Log $bStr $dbStr "ERROR" "Bad exitcode CPL: $dcbPfn"
        # log special error to Master Log
    }
    CF-Log-To-Master-Log $bStr $dbStr "STATUS" "Finish dcb: $dcbPfn"

}   

function Main {
    $runEnv = CF-Init-RunEnv $BatchID
    $CN_EXE = $CF_CN_V8_EXE
    
    Set-Up-CPT $Vstr
    
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
