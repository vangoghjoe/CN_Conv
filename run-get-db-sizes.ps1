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
    $outFile,
    $DriverFile,
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
        $ttlSize = $numFiles = 0

        # Load driver file, if using
        if ($DriverFile) {
            CF-Load-Driver-File $DriverFile
        }

        $dcbRows = CF-Read-DB-File "DCBs" "BatchID" $BatchID

        # Setup start/stop rows (assume user specifies as 1-based)
        if ($startRow -eq $null) { $startRow = 1 }
        if ($endRow -eq $null) { $endRow = $dcbRows.length } 
        CF-Log-To-Master-Log $runEnv.bstr "" "STATUS" "Start row=$startRow  End row=$endRow"
         
        # Main loop
        for($i = ($startRow-1) ; $i -lt $endRow ; $i++) {
            $row = $dcbRows[$i]
            
            # Only process this row if it's in the right batch 
            # and has the right status
            if ($row.batchid -ne $BatchID) {
                continue
            }

            # Check against driver file, if using
            if ($DriverFile) {
                if (-not (CF-Is-DBID-in-Driver $row.dbid)) {
                    continue
                }
            }
            # process this row  (sorry, just here in one big blob of a function)
            $dcb = $row.orig_dcb
            $dir = [system.io.path]::GetDirectoryName($dcb)

            # If present, get size: else leave size blank
            ($row.db_bytes, $row.db_files) = CF-Get-Num-Files-And-Size-Of-Folder $dir
            $ttlSize += $size
            $ttlNumFiles += $numFiles

            # Write $db  $size $numFiles, tab delimited 
            $msg = (@($dcb, $row.db_bytes, $row.db_files) -join "`t")
            write-host $msg

            # Write out whole DB every time in case stop before end of run
            CF-Write-DB-File "DCBs" $dcbRows
        }
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

