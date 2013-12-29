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
    $startRow,
    $endRow
)

set-strictmode -version latest
. ((Split-Path $script:MyInvocation.MyCommand.Path) + "/libConversion.ps1")

function IsAlpha4($word) {
    return $word -match "^[A-Za-z]{4,}$"
}

function IsAlphaNum4() {
    return $word -match "^[A-Za-z][A-Za-z0-9]{3,}$"
}

function AddToResFile () {
    if (-not ($script:qcwords.containskey($word))) {
        CF-Write-File $resFilePFN $word
        $script:qcwords[$word] = ""
        if ($script:qcwords.count -ge $numWanted) {
            return $true
        }
        else { return $false }
    }
    else { return $false }
}

# Picks the words and writes tehm ot    
function Pick-QC-Words ($dictListFile, $resFilePFN) {
    $numWanted = 3
    echo $null > $resFilePFN
    # Get up to $numWanted words
    # first, try to fill all with alpha >= 4 chars
    # if that fails, get alpha + 3 or more alphanum
    # else take what we can get except for tokens containing doublequotes
    # File format is just one dictionary word per line
    #$words = get-content $dictListFile
    $script:qcwords = @{}
    $isDone = $false

    # All alpha
    $reader = [System.IO.File]::OpenText("$dictListFile")
    try {
        for(;;) {
            $word = $reader.ReadLine()
            if ($word -eq $null) { break }
            if (IsAlpha4 $word) {
                if (AddToResFile) { $isDone = $true; break }
            }
        }
    }
    finally {
        $reader.Close()
    }
    if ($isDone) { return }    

    # Alpha + alphanum
    $reader = [System.IO.File]::OpenText("$dictListFile")
    try {
        for(;;) {
            $word = $reader.ReadLine()
            if ($word -eq $null) { break }
            if (IsAlphaNum4 $word) {
                if (AddToResFile) { $isDone = $true; break }
            }
        }
    }
    finally {
        $reader.Close()
    }
    if ($isDone) { return }    

    # Anything except with double-quotes
    # NOTE: if Modify punctuation, double-quotes embedded in strings can 
    # be in a index word, but I don't know how to search for it
    # Eg  aaa"doublequote   will be in dictionary
    #    but "aaa"doublequote"  and 'aaa"doubleqouote' 
    #    both throw errors when searching
    $reader = [System.IO.File]::OpenText("$dictListFile")
    try {
        for(;;) {
            $word = $reader.ReadLine()
            if ($word -eq $null) { break }
            if (!($word -match '"')) {
                if (AddToResFile) { $isDone = $true; break }
            }
        }
    }
    finally {
        $reader.Close()
    }
    if ($isDone) { return }    
}

function Process-Row($dbRow, $runEnv) {
    # Inits
    # Inits
    $bStr = $runEnv.bStr
    $dbid = $dbRow.dbid
    $dbStr = "{0:0000}" -f [int]$dbid

    ($script:statusFilePFN, $resFilePFN) = CF-Init-RunEnv-This-Row2 $runEnv $dbRow
    $script:rowHasError = $false

    try {

        # Calc results file for the dict-list
        $v8FileStub = $CF_PGMS['run-qc-list-dict-v8'][1];
        $v8ResFilePFN = "${bStr}_${dbStr}_${v8FileStub}.txt"
        $v8ResFilePFN =  "$($runEnv.SearchResultsDir)\$v8ResFilePFN"

        CF-Write-Progress $dbid ""
        Pick-QC-Words $v8ResFilePFN $resFilePFN

    }
    catch {
        CF-Write-Log $script:statusFilePFN "|ERROR|$($error[0])"
        $script:rowHasError = $true
    }
    CF-Finish-Log $script:statusFilePFN 
}

function Main {
    $startdate = $(get-date -format $CF_DateFormat)
    $rowsCompared = 0
    $runEnv = CF-Init-RunEnv $BatchID 
    $dcbRows = CF-Read-DB-File "DCBs" "BatchID" $BatchID

    # Setup start/stop rows (assume user specifies as 1-based)
    if ($startRow -eq $null) { $startRow = 1 }
    if ($endRow -eq $null) { $endRow = $dcbRows.length } 
    CF-Log-To-Master-Log $runEnv.bstr "" "STATUS" "Start row=$startRow  End row=$endRow"
     
    # DCB Rows Loop
    for ($i = ($startRow-1) ; $i -lt $endRow ; $i++) {
        $row = $dcbRows[$i]
        $arrPreReqs = @()
        $arrPreReqs += $row.st_qc_list_dict_v8
        if (CF-Skip-This-Row $runEnv $row $arrPreReqs) {
            continue
        }

        Process-Row $row $runEnv 
    }

    CF-Log-To-Master-Log $runEnv.bstr "" "STATUS" "STOP  Start row=$startRow  End row=$endRow"
    $endDate = $(get-date -format $CF_DateFormat)
    write-host "*** Done: batch = $BatchID Start row=$startRow  End row=$endRow"
    write-host "Start: $startDate"
    write-host "End:   $endDate"
}
Main


