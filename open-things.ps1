param(
    $DBId,
    [switch]$OrigDCB,
    [switch]$ConvDCB,
    [switch]$File,
    [switch]$Dir,
    [switch]$Var
)


. ((Split-Path $script:MyInvocation.MyCommand.Path) + "/libConversion.ps1")

function Get-DBRow-By-ID($dbrows, $dbid) {
    for($i =0 ; $i -lt $dbrows.length ; $i++) {
        $row = $dbRows[$i]
        if ($row.dbid -eq "$dbid") { return $row }
    }
    throw "ERROR: Can't find dbid '$dbid' in DB."
}

function Main {
    # Bare inits to write to master log
    write-host "origdcb = $origdcb convdcb = $ConvDCB dir=$dir file=$file dbid=$dbid"
    $runEnv = CF-Init-RunEnv $BatchID
    $dbRows = CF-Read-DB-File "DCBs" "BatchID" $BatchID
    $row = Get-DBRow-By-ID $dbRows $DBId


    if ($OrigDCB) {
        $pfn = $row.orig_dcb
    }
    elseif ($ConvDCB) {
        $pfn = $row.conv_dcb
    }

    write-host "pfn = $pfn"

    if ($Dir) {
        write-host "in dir"
        $item = [system.io.path]::GetDirectoryName($pfn)
    }
    else {
        if ($OrigDCB) {
            throw "ERROR: Not allowed to open orig dcb, only the orig dir"
        }
        $item = $pfn
    }

    write-host "item = $item"
    if ($Var) { return $item }
    else {invoke-item $item }

}

Main
