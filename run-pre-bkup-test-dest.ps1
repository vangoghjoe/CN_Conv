[CmdLetBinding()]
param(
    $BatchID,
    [switch] $ignoreStatus,
    $DBId,
    $DriverFile,
    $startRow,
    $endRow,
    $outFile
)

set-strictmode -version latest
. ((Split-Path $script:MyInvocation.MyCommand.Path) + "/libConversion.ps1")

function Process-Row($dbRow, $runEnv) {
    $script:rowHasError = $false
    
    $orig = $dbrow.orig_dcb
    $new = $orig -replace "X:", "W:"
    if ((test-path "$new")) {
        $script:presentCt++
        if ($script:presentCt -eq 1) { 
            echo $null > $outFile
        }

        $msg = "$new"
        CF-Write-File $outFile $msg
    }
}

function Main {
    $startdate = $(get-date -format $CF_DateFormat)
    $rowsCompared = 0
    #$runEnv = CF-Init-RunEnv $BatchID 
    $dcbRows = CF-Read-DB-File "DCBs" "BatchID" $BatchID

    # Setup start/stop rows (assume user specifies as 1-based)
    if ($startRow -eq $null) { $startRow = 1 }
    if ($endRow -eq $null) { $endRow = $dcbRows.length } 
     
    # DCB Rows Loop
    $ignoreStatus = $true
    $script:presentCt = 0
    for ($i = ($startRow-1) ; $i -lt $endRow ; $i++) {
        $row = $dcbRows[$i]
        $arrPreReqs = @()
        if (CF-Skip-This-Row "" $row $arrPreReqs $true) {
            continue
        }
        write-verbose "process: $($row.dbid)"
        Process-Row $row ""
    }
    echo "$presentCt already there"
}
Main
