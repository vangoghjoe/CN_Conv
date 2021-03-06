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

# local 7/10 3:45P
param(
    $BatchID
)


. ((Split-Path $script:MyInvocation.MyCommand.Path) + "/libConversion.ps1")


function Set-Up-CPT () {
    $CPT_name = "Hogan-Issue-To-Tag.CPT"
    
    if ($(hostname) -eq "LNGHBEL-5009970") {
        $CPT_DEV_DIR = "C:\Documents and Settings\hudsonj1\My Documents\Hogan\CPLs\"
        $CPT = "C:\Conversions\$CPT_name"
        copy-item -Force "$CPT_DEV_DIR\$CPT_name" "$CPT"
    }
    else {
        $CPT = "$CF_ScriptDir\$CPT_name"
    }

    # make sure CPT name doesn't have whitespace
    if ($CPT -match "\s") {
        write-host "FATAL ERROR: .cpt path cannot contain whitespace: $CPT"
    }
    $script:CPT = $CPT
}



function Exec-CPL {
    param (
        $dbRow,
        $runEnv,
        $CN_EXE
    )
    $bStr = $runEnv.bStr
    
    $dbid = $dbRow.dbid
    $dcbPfn = $dbRow.conv_dcb;
    
    $dbStr = "{0:0000}" -f [int]$dbid
    $dcbDir = [system.io.path]::GetDirectoryName($dcbPfn)
    $statusFile = "${bStr}_${dbStr}_issue-to-tag_STATUS.txt"
    #$localResFilePFN = "$dcbDir\$CF_LocaldcbDir
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

}   

function Main {
    $runEnv = CF-Init-RunEnv $BatchID
    
    $CN_EXE = $CF_CN_V8_EXE
    
    Set-Up-CPT 
    
    CF-Log-To-Master-Log $runEnv.bstr "" "STATUS" "START"
    $dcbRows = CF-Read-DB-File "DCBs" "BatchID" $BatchID
    foreach ($row in $dcbRows) {

        if ($row.batchid -ne $BatchID) {   
            continue
        }
        write $row.conv_dcb;
        Exec-CPL $row $runEnv  $CN_EXE 
    }
    CF-Log-To-Master-Log $runEnv.bstr "" "STATUS" "STOP"
}

Main
