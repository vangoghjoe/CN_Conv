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
    
    $orig = $dbrow.orig_cb
    $new = $orig -replace "X:", "W:"
    if ((test-path "$($dbrow.orig_dcb)")) {
        if ($script:missct -eq 1) { 
            echo $null > $outFile
        }
        $msg = "$($dbrow.client_matter)`t$($dbrow.orig_dcb)"
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
    $script:missct = 0
    for ($i = ($startRow-1) ; $i -lt $endRow ; $i++) {
        $row = $dcbRows[$i]
        $arrPreReqs = @()
        if (CF-Skip-This-Row "" $row $arrPreReqs $true) {
            continue
        }
        write-verbose "process: $($row.dbid)"
        Process-Row $row ""
    }
    echo "$missct missing"
}
Main
