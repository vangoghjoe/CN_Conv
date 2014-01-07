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
    $startRow,
    $endRow,
    [switch] $ignoreStatus,
    $DriverFile,
    $DBId,
    $fileSet   # O = orig  S = localv8  C = conv
)

set-strictmode -version latest

. ((Split-Path $script:MyInvocation.MyCommand.Path) + "/libConversion.ps1")


function Process-Row {
    param (
        $dbRow,
        $runEnv,
        $fileSet
    )
    $script:rowHasError = $false
    try {
        $bStr = $runEnv.bStr
        $dbid = $dbRow.dbid
        $sCmd = $runEnv.sCmd

        if ($fileSet -eq 'O') {
            $dcbPfn = $dbRow.orig_dcb;
        }
        elseif ($fileSet -eq 'S') {
            $dcbPfn = $dbRow.local_v8_dcb;
        }
        else {
            $dcbPfn = $dbRow.conv_dcb;
        }
        
        $dbStr = "{0:0000}" -f [int]$dbid
        $statusFile = "${bStr}_${dbStr}_${fileSet}_get_sizes_STATUS.txt"
        $script:statusFilePFN =   "$($runEnv.ProgramLogsDir)\$statusFile"
        echo $null > $script:statusFilePFN
        
        CF-Log-To-Master-Log $bStr $dbStr "STATUS" "Start get sizes $CN_Ver: $dcbPfn"

        # Remove any existing entries for this db, for this srcDir
        $t = "DELETE FROM CN_Files WHERE "
        $t += "batchid=$batchid AND dbid=$dbid AND fileset='$fileset'" 
        $sCmd.CommandText = $t
        $sCmd.ExecuteNonQuery() > $null
        if (($dbid % 10) -eq 0) { write-host $dbid }

        $files = CF-Get-DbFiles $dcbPfn
        foreach ($file in $files) {
            # don't worry about using params
            $ext = $([system.io.path]::GetExtension($file)).substring(1).ToUpper()
            $size = $file.length
            $t = "INSERT INTO CN_Files (batchid, dbid, fileset, ext, size)"
            $t += " VALUES($batchid, $dbid, '$fileset','$ext', $size)"
            $sCmd.CommandText = $t
            $sCmd.ExecuteNonQuery() > $null
        }

    }
    catch {
        CF-Write-Log $script:statusFilePFN "|ERROR|$($error[0])"
        $script:rowHasError = $true
    }
    CF-Finish-Log $script:statusFilePFN 

}   

function Main {
    
    $runEnv = CF-Init-RunEnv $BatchID 
    CF-Log-To-Master-Log $runEnv.bstr "" "STATUS" "Start row=$startRow  End row=$endRow"
    $runEnv["sCmd"] = CF-Get-SQL-Cmd "FYI_Conversions"

    $dcbRows = CF-Read-DB-File "DCBs" "BatchID" $BatchID
    $startDate = $(get-date -format $CF_DateFormat)

    if ($fileSet -eq $null) { $fileSet = 'C' }

    # Setup start/stop rows (assume user specifies as 1-based)
    if ($startRow -eq $null) { $startRow = 1 }
    if ($endRow -eq $null) { $endRow = $dcbRows.length } 
    # DCB Rows Loop
    for ($i = ($startRow-1) ; $i -lt $endRow ; $i++) {
        $row = $dcbRows[$i]

        $arrPreReqs = @()
        if ($fileSet -eq 'S') {
                $arrPreReqs += $row.st_backup_local_v8
        }
        else {
            $arrPreReqs += $row.st_backup
        }
        if (CF-Skip-This-Row $runEnv $row $arrPreReqs) {
            continue
        }
        Process-Row $row $runEnv $fileSet
    }

    CF-Log-To-Master-Log $runEnv.bstr "" "STATUS" "STOP Fileset='$fileset' Start row=$startRow  End row=$endRow"
    $endDate = $(get-date -format $CF_DateFormat)
    write-host "*** Done: batch = $BatchID Fileset='$fileset' Start row=$startRow  End row=$endRow"
    write-host "Start: $startDate"
    write-host "End:   $endDate"
}     

Main
