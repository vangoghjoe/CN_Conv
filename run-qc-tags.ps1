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
[CmdLetBinding()]
param(
    $BatchID,
    $startRow,
    $endRow,
    [switch] $ignoreStatus,
    $DBId,
    [switch]$UseMultiFilesets,
    $CN_Ver
)

set-strictmode -version latest

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

    if ($Vstr -match '8') {
        if ($UseMultiFilesets) {
            $dcbPfn = $dbRow.local_v8_dcb;
        }
        else {
            $dcbPfn = $dbRow.conv_dcb;
        }
    }
    else {
        $dcbPfn = $dbRow.conv_dcb;
    }
    $dcbDir = [system.io.path]::GetDirectoryName($dcbPfn)
    
    $dbStr = "{0:0000}" -f [int]$dbid
    $resFile = "${bStr}_${dbStr}_${VStr}_tagging.txt"
    $statusFile = "${bStr}_${dbStr}_${VStr}_tagging_STATUS.txt"
    #$localResFilePFN = "$dcbDir\$CF_LocaldcbDir
    $batchResFilePFN = CF-Encode-CPL-Safe-Path "$($runEnv.SearchResultsDir)\$resFile"
    $statusFilePFN =  CF-Encode-CPL-Safe-Path "$($runEnv.ProgramLogsDir)\$statusFile"
    
    $safeDcbPfn = CF-Encode-CPL-Safe-Path $dcbPfn
    $myargs = @("/nosplash", $CPT, $safeDcbPfn, $batchResFilePFN, $statusFilePFN)
    CF-Log-To-Master-Log $bStr $dbStr "STATUS" "Start dcb: $dcbPfn"
    CF-Write-Progress $dbid $dcbPfn
    write-verbose ($myargs -join "`n")
    $proc = (start-process $CN_EXE -ArgumentList $myargs -Wait -NoNewWindow -PassThru)
    if ($proc.ExitCode -gt 1) {
        CF-Log-To-Master-Log $bStr $dbStr "ERROR" "Bad exitcode CPL: $dcbPfn"
        # log special error to Master Log
    }
    CF-Log-To-Master-Log $bStr $dbStr "STATUS" "Finish dcb: $dcbPfn"

}   

function Main {
    
    ($Vstr, $script:CN_EXE) = CF-Get-CN-Info $CN_Ver 
    Set-Up-CPT $Vstr
    $runEnv = CF-Init-RunEnv $BatchID $Vstr
    $dcbRows = CF-Read-DB-File "DCBs" "BatchID" $BatchID

    $startDate = $(get-date -format $CF_DateFormat)

    # Setup start/stop rows (assume user specifies as 1-based)
    if ($startRow -eq $null) { $startRow = 1 }
    if ($endRow -eq $null) { $endRow = $dcbRows.length } 
    if ($endRow -gt $dcbRows.length) { $endRow = $dcbRows.length }
    CF-Log-To-Master-Log $runEnv.bstr "" "STATUS" "Start CN=$Vstr row=$startRow  End row=$endRow"
     
    # DCB Rows Loop
    for ($i = ($startRow-1) ; $i -lt $endRow ; $i++) {
        $row = $dcbRows[$i]
        $arrPreReqs = @()
        if ($Vstr -eq 'v8') {
            if ($UseMultiFilesets) {
                $arrPreReqs += $row.st_backup_local_v8
            }
            else {
                $arrPreReqs += $row.st_backup
            }
        }
        else {
            $arrPreReqs += $row.st_convert_one_dcb
        }
       
        if (CF-Skip-This-Row $runEnv $row $arrPreReqs) {
            continue
        }

        Exec-Get-Tags $row $runEnv  $CN_EXE $VStr
        # take ownership of this row, this step
    }

    CF-Log-To-Master-Log $runEnv.bstr "" "STATUS" "STOP CN=$Vstr Start row=$startRow  End row=$endRow"
    $endDate = $(get-date -format $CF_DateFormat)
    write-host "*** Done: batch = $BatchID CN=$Vstr Start row=$startRow  End row=$endRow"
    write-host "Start: $startDate"
    write-host "End:   $endDate"
}     

Main
