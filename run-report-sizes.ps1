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
    $ignoreStatus = $false,
    [Parameter(mandatory=$true)]
    $outFile,
    $startRow,
    $endRow
)


. ((Split-Path $script:MyInvocation.MyCommand.Path) + "/libConversion.ps1")

function Main {
    # Minimum necessary to make entry in master log
    $runEnv = CF-Init-RunEnv $BatchID
    CF-Log-To-Master-Log $runEnv.bstr "" "STATUS" "START"

    try {
        # Inits 
        $ttlBytes = $ttlFiles = $ttlMiss = 0
        $dcbRows = CF-Read-DB-File "DCBs" "BatchID" $BatchID
        rm $outFile 2>&1 >$null

        # Setup start/stop rows (assume user specifies as 1-based)
        if ($startRow -eq $null) { $startRow = 1 }
        if ($endRow -eq $null) { $endRow = $dcbRows.length } 
        CF-Log-To-Master-Log $runEnv.bstr "" "STATUS" "Start row=$startRow  End row=$endRow"
         
        CF-Write-File $outFile (@("Matter", "DCB", "Ttl Size (GB)", "Ttl Files Present", "Ttl Files Missing","Backup Done", "DB Size(B)", "DB Files", "Natives Size(B)", "Natives Present", "Natives Missing", "Images Size(B)","Images Present", "Images Missing") -join "`t")
        # Main loop
        for($i = ($startRow-1) ; $i -lt $endRow ; $i++) {
            $row = $dcbRows[$i]
            
            # Only process this row if it's in the right batch 
            # and has the right status
            if ($row.batchid -ne $BatchID) {
                continue
            }

            [int64]$rowBytes = [int64]$row.db_bytes + [int64]$row.natives_bytes + [int64]$row.images_bytes
            [int64]$rowFiles = [int64]$row.db_files + [int64]$row.natives_files_present + [int64]$row.images_files_present
            [int64]$rowMiss = [int64]$row.natives_files_missing + [int64]$row.images_files_missing
            #write-host (@($rowBytes, $row.db_bytes, $row.natives_bytes, $row.images_bytes) -join "|")
            $ttlBytes += $rowBytes
            $ttlFiles += $rowFiles
            $ttlMiss += $rowMiss

            # Write to file, tab delimited
            CF-Write-File $outFile (@($row.clientid, $row.orig_dcb, ($rowBytes/1GB), $rowFiles, $rowMiss, $row.backup_done, $row.db_bytes, $row.db_files, $row.natives_bytes, $row.natives_files_present, $row.natives_files_missing, $row.images_bytes, $row.images_files_present, $row.images_files_missing) -join "`t")
            $msg = (@($dcb, $row.db_bytes, $row.db_files) -join "`t")
            write-host $msg

        }
        write-host (@($ttlBytes, $ttlFiles, $ttlMiss), "`t")
    }
    catch {
        $error[0] | format-list
        CF-Log-To-Master-Log $runEnv.bstr "" "ERROR" "$($error[0])"
    }

    # Wrap up
    write-host "*** Done: batch = $BatchID Start row=$startRow  End row=$endRow"
    CF-Log-To-Master-Log $runEnv.bstr "" "STATUS" "STOP"
}     

Main

