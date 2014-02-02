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

# local 7/23 12 noon
param(
    [parameter(mandatory=$true)]
    $BatchID,
    [switch]$UseMultiFileSets,
    [switch]$ignoreStatus,
    [switch]$ImageBaseOnly,
    $DBid,
    $DriverFile,
    $startRow,
    $endRow
)

set-strictmode -version latest

. ((Split-Path $script:MyInvocation.MyCommand.Path) + "/libConversion.ps1")


function Set-Up-CPT () {
    if ($ImageBaseOnly) {
        $CPT_name = "convert-one-imagebase.CPT"
    }
    else {
        $CPT_name = "convert-one-dcb.CPT"
    }
    write-verbose "cpt name is : $CPT_name"
    
    if ($(hostname) -eq "LNGHBEL-5009970") {
        $CPT_DEV_DIR = "C:\Documents and Settings\hudsonj1\My Documents\Hogan\Scripts\CPLs"
        $CPT = "C:\Conversions\$CPT_name"
        copy-item -Force "$CPT_DEV_DIR\$CPT_name" "$CPT"
    }
    else {
        $CPT = "$CF_ScriptDir\CPLs\$CPT_name"
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
    if ($ImageBaseOnly) { 
        $statusFile = "${bStr}_${dbStr}_convert-one-imagebase_STATUS.txt"
    }
    else {
        $statusFile = "${bStr}_${dbStr}_convert-one-dcb_STATUS.txt"
    }
    #$localResFilePFN = "$dcbDir\$CF_LocaldcbDir
    $statusFilePFN =  CF-Encode-CPL-Safe-Path "$($runEnv.ProgramLogsDir)\$statusFile"
    
    $safeDcbPfn = CF-Encode-CPL-Safe-Path $dcbPfn
    $myargs = @("/nosplash", $CPT, $safeDcbPfn, $statusFilePFN)
    CF-Write-Progress $dbid $dcbPfn
    CF-Log-To-Master-Log $bStr $dbStr "STATUS" "Start dcb: $dcbPfn"

    $proc = (start-process $CN_EXE -ArgumentList $myargs -Wait -NoNewWindow -PassThru)
    if ($proc.ExitCode -gt 1) {
        CF-Log-To-Master-Log $bStr $dbStr "ERROR" "Bad exitcode CPL: $dcbPfn"
        # log special error to Master Log
    }
    CF-Log-To-Master-Log $bStr $dbStr "STATUS" "Finish dcb: $dcbPfn"

}   

function Main {
    $startdate = $(get-date -format $CF_DateFormat)
    $runEnv = CF-Init-RunEnv $BatchID
    
    $CN_Ver = 10
    ($Vstr, $script:CN_EXE) = CF-Get-CN-Info $CN_Ver 
    Set-Up-CPT 

    try { 
        CF-Log-To-Master-Log $runEnv.bstr "" "STATUS" "START"
    }
    catch {
        CF-Fatal-Error $_.Exception.
    }
    $dcbRows = CF-Read-DB-File "DCBs" "BatchID" $BatchID

    if ($startRow -eq $null) { $startRow = 1 }
    if ($endRow -eq $null) { $endRow = $dcbRows.length } 
    CF-Log-To-Master-Log $runEnv.bstr "" "STATUS" "Start CN=$Vstr row=$startRow  End row=$endRow"
     
    # DCB Rows Loop
    for ($i = ($startRow-1) ; $i -lt $endRow ; $i++) {
        $row = $dcbRows[$i]

        $arrPreReqs = @()
        # if Multi sets, then the v8 qc is in a different dir than the conversions.
        # So, the conversions can start as soon as the conv bkups are done
        # But if not, all the v8 Qc steps have to be run first
        # NB: "st_backup" is for the conv backup, as opposed to st_backup_local_v8
        if ($ImageBaseOnly) {
            $ignoreStatus = $true
        }
        else {
            if ($UseMultiFileSets) {
                $arrPreReqs = @($row.st_backup)
            }
            else {
                $arrPreReqs += $row.st_qc_v8_tags
                $arrPreReqs += $row.st_qc_query_dict_v8
            }
        }
        write-verbose "ib = $ImageBaseOnly  $($row.dbid) $($row.batchid)"
        if (CF-Skip-This-Row $runEnv $row $arrPreReqs) {
            continue
        }

        write $row.conv_dcb;
        Exec-CPL $row $runEnv $CN_EXE 
    }
    CF-Log-To-Master-Log $runEnv.bstr "" "STATUS" "STOP CN=$Vstr Start row=$startRow  End row=$endRow"
    $endDate = $(get-date -format $CF_DateFormat)
    write-host "*** Done: batch = $BatchID CN=$Vstr Start row=$startRow  End row=$endRow"
    write-host "Start: $startDate"
    write-host "End:   $endDate"
}

Main
