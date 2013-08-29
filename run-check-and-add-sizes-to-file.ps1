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
    [Parameter(Mandatory=$true)]
    $BatchID,
    [Parameter(Mandatory=$true)]
    $outFile,
    [Parameter(Mandatory=$true)]
    $missFile,
    [Parameter(Mandatory=$true)]
    $errFile,
    $ignoreStatus = $false,
    $startRow,
    $endRow
)


. ((Split-Path $script:MyInvocation.MyCommand.Path) + "/libConversion.ps1")

# Take a file and return its size, or -1 if doesn't exist
function Get-File-Size($file) {

    # have to check $? *immediately* after call to test-path
    # can't even be like if (-not (test-path blut)) ...
    $mytest = test-path $file 2>null
    $last = $?
    if (-not ($mytest)) {
        #write-host ("test-path neg: last val = " + $last + " $file")
        return @(-1, $last)
    }
    else {
        $len = (get-item $file).length
        return @($len, $true)
    }
}

# Take a type (db, natives, images)
# sets size/num_files in db
# makes a result file of missings
function Process-Type($type, $listFile, $outFile, $missFile, $errFile, $dbRow) {
    # Inits
    $line = 0
    $numMiss = $numPresent = $ttlSize = 0

    # read listFile and gather stats
    $files = get-content $listFile 
    foreach ($file in $files) {
        $line++

        # skip blank lines
        if ($file -match '^\s*$') {
            continue
        }

        try {
            ($size, $lastExitStat) = Get-File-Size $file
            
            # missing?
            if ($size -eq -1) {
                $numMiss++
                if ($lastExitStat -eq $false) {
                    CF-Write-File $missFile ($dbRow.orig_dcb +"`t$type`t$file`twarning when testing path, probably too long or bad format")
                }
                else {
                    CF-Write-File $missFile ($dbRow.orig_dcb +"`t$type`t$file")
                }
            }
            else {
                $numPresent++
                $ttlSize += $size
            }
        }
        catch {
            CF-Write-File $errFile (@($dbrow.orig_dcb, $type, "ERROR", "ERROR") -join "`t")
        }
    }

    # Append results to $outFile
    CF-Write-File $outFile (@($dbrow.orig_dcb, $type, $ttlSize, $numFiles) -join "`t")
    write-host "$type: present = $numPresent  miss = $numMiss bytes = $ttlSize"
}

# Process the list files for a given row
# Verifies status of each type (db, natives and images) before calling
function Process-Row($dbRow, $runEnv) {

    # Inits
    $bStr = $runEnv.bStr
    $dbid = $dbRow.dbid
    $dcbPfn = $dbRow.conv_dcb;
    $dbStr = "{0:0000}" -f [int]$dbid

    # Loop over types, setting listFile and calling Process-Type
    try {
        #foreach ($type in @("dbfiles", "natives", "images")) {
        foreach ($type in @("natives", "images")) {
            if ($type -eq "images") {
                $listFilePFN =   "${bStr}_${dbStr}_${type}_ALL.txt"
            }
            else {
                $listFilePFN =   "${bStr}_${dbStr}_${type}.txt"
            }
            $listFilePFN = "$($runEnv.SearchResultsDir)\$listFilePFN"
            if (test-path $listFilePFN) {
                Process-Type $type $listFilePFN $outFile $missFile $errFile $dbRow
            }
            else {
                CF-Write-File $outFile (@($dbrow.orig_dcb, $type, "missing", "missing") -join "`t")
                write-host "No list file: $($dbRow.dbid) $type"
            }
        }
    }
    catch {
        CF-Write-File $errFile "|ERROR|$($error[0])"
        $script:rowHasError = $true
    }
}

function Main {
    $runEnv = CF-Init-RunEnv $BatchID
    CF-Log-To-Master-Log $runEnv.bstr "" "STATUS" "START"

    try {
        # Inits
        $dcbRows = CF-Read-DB-File "DCBs" "BatchID" $BatchID
        #   Remove output files
        foreach ($file in @($outFile, $missFile, $errFile)) {
            rm $file 2>&1 > $null
        }
        #   Setup start/stop rows (assume user specifies as 1-based)
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

            Process-Row $row $runEnv  
        }
    }
    catch {
        $error[0] | format-list
        CF-Log-To-Master-Log $runEnv.bstr "" "ERROR" "$($error[0])"
    }

    write-host "*** Done: batch = $BatchID Start row=$startRow  End row=$endRow"

    CF-Log-To-Master-Log $runEnv.bstr "" "STATUS" "STOP"
}     

Main

