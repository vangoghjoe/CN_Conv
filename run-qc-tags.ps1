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

# VERSION: remote 7/26 7:27 P PST
param(
    $BatchID,
    $CN_Ver
)


. ((Split-Path $script:MyInvocation.MyCommand.Path) + "/libConversion.ps1")


function Set-Up-CPT ($Vstr) {
    $CPT_name = "Hogan-Query-Tags-${Vstr}.CPT"
    
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



function Exec-Get-Tags {
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
    $resFile = "${bStr}_${dbStr}_${VStr}_tagging.txt"
    $statusFile = "${bStr}_${dbStr}_${VStr}_tagging_STATUS.txt"
    #$localResFilePFN = "$dcbDir\$CF_LocaldcbDir
    $batchResFilePFN = CF-Encode-CPL-Safe-Path "$($runEnv.SearchResultsDir)\$resFile"
    $statusFilePFN =  CF-Encode-CPL-Safe-Path "$($runEnv.ProgramLogsDir)\$statusFile"
    
    $safeDcbPfn = CF-Encode-CPL-Safe-Path $dcbPfn
    $myargs = @("/nosplash", $CPT, $safeDcbPfn, $batchResFilePFN, $statusFilePFN)
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
    
    ($Vstr, $script:CN_EXE) = CF-Get-CN-Info $CN_Ver 
    Set-Up-CPT $Vstr
    Set-Up-CPT $Vstr
    
    CF-Log-To-Master-Log $runEnv.bstr "" "STATUS" "START"

    # 11/23/13
    # For now, when this is invoked, it will try to process all DBs
    # in the future, may use a command-line switch to tell it which DB to process
    # and then could another pgm could call it
    # Will only process DB's where 
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

        $statVal = $row.$($runEnv.StatusField) 

        if ($statVal -ne $CF_STATUS_READY) {
            continue
        }

        if ($row.st_backup -ne $CF_STATUS_GOOD) {
            continue
        }

        Exec-Get-Tags $row $runEnv  $CN_EXE $VStr
        # take ownership of this row, this step
    }

    CF-Log-To-Master-Log $runEnv.bstr "" "STATUS" "STOP"
}     

Main
