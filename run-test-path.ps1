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
    [switch] $SrcOrig,
    [switch] $SrcRealConv,
    [switch] $SrcLocalV8,
    [switch] $SrcConv,
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
    
    if ($SrcOrig) {
        $file = $dbrow.orig_dcb
    }
    elseif ($SrcLocalV8) {
        $file = $dbrow.local_v8_dcb
    }
    elseif ($SrcConv) {
        $file = $dbrow.conv_dcvb
    }
    elseif ($SrcRealConv) {
        $file = $dbrow.orig_dcb -replace "X:","W:"
    }

    write-verbose "File = $file"

    if ((test-path "$file")) {
        $script:missct++
        if ($script:missct -eq 1) { 
            echo $null > $outFile
        }
        $msg = "$($dbrow.dbid)`t$($dbrow.client_matter)`t$file"
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
