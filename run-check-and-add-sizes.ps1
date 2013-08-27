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
    $CN_Ver
)


. ((Split-Path $script:MyInvocation.MyCommand.Path) + "/libConversion.ps1")


# Take a file and return its size, or -1 if doesn't exist
function Get-File-Size($file) {
    if (-not (test-path $file)) {
        return -1
    }
    else {
        $len = (get-item $file).length
        return $len
    }
}

# Take a type (db, natives, images)
# sets size/num_files in db
# makes a result file of missings
function Process-Type($type, $listFile, $missFile, $dbRow) {
    # Inits
    $line = 0
    $numMiss = 0
    CF-Initialize-Log $missFile

    # read listFile and gather stats
    $files = get-content $listFile 
    foreach ($file in $files) {
        $line++

        # skip blank lines
        if ($file -match '^\s*$') {
            continue
        }


        try {
            $size = Get-File-Size $file
            
            # missing?
            if ($size -eq -1) {
                $numMiss++
                CF-Write-File $missFile ($dbRow.orig_dcb +"`t$type`t$file")
            }
            else {
                $numPresent++
                $ttlSize += $size
            }
        }
        catch {
            CF-Write-Log $script:statusFilePFN "|ERROR|Can't get size [line $line]: $file: $($error[0])"
        }
    }

    # Save stats in DB by setting values in row
    # kind of kludgy, but ...
    switch ($type) {
        "db" {
            $dbRow.db_bytes = $ttlSize
            $dbRow.db_files = $numPresent
        }
        "natives" {
            $dbRow.natives_bytes = $ttlSize
            $dbRow.natives_files_present = $numPresent
            $dbRow.natives_files_missing = $numMiss
        }
        "images" {
            $dbRow.images_bytes = $ttlSize
            $dbRow.images_files_present = $numPresent
            $dbRow.images_files_missing = $numMiss
        }
    }

}

# Process the list files for a given row
# Verifies status of each type (db, natives and images) before calling
function Process-Row($dbRow, $runEnv) {

    # Inits
    $bStr = $runEnv.bStr
    $dbid = $dbRow.dbid
    $dcbPfn = $dbRow.conv_dcb;
    $dbStr = "{0:0000}" -f [int]$dbid
    $missFile = "${bStr}_${dbStr}_arch_missing.txt"
    $statusFile = "${bStr}_${dbStr}_check-and-add-sizes_STATUS.txt"
    $missFilePFN = "$($runEnv.SearchResultsDir)\$missFile"
    if (test-path $missFilePFN) {
        rm $missFilePFN
    }

    $script:statusFilePFN =  "$($runEnv.ProgramLogsDir)\$statusFile"
    CF-Initialize-Log $script:statusFilePFN
    write-host $script:statusFilePFN
    $script:rowHasError = $false

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
                Process-Type $type $listFilePFN $missFilePFN $dbRow
            }
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
    CF-Log-To-Master-Log $runEnv.bstr "" "STATUS" "START"

    try {

        $dcbRows = CF-Read-DB-File "DCBs" "BatchID" $BatchID
         
        # going to write to batchResult File
        # status to batchStatus = 1 per DB per pgm
        #  steps table in db can have separate field for step name and pgm-that-does-step
        # if processing breadth first, step name can be ALL STEPS

        for($i = 0 ; $i -lt $dcbRows.length; $i++) {
            $row = $dcbRows[$i]
            
            # Only process this row if it's in the right batch 
            # and has the right status
            if ($row.batchid -ne $BatchID) {
                continue
            }
            if (($row.$statusFld -eq $CF_STATUS_IN_PROGRESS) -or
                ($ignoreStatus=$false -and ($row.statusFld -eq $CF_STATUS_GOOD))) {
                continue
            }

            Process-Row $row $runEnv  
        }
        # Finished with all the rows.  Rewrite the whole DB file
        CF-Write-DB-File "DCBs" $dcbRows
    }
    catch {
        $error[0] | format-list
        CF-Log-To-Master-Log $runEnv.bstr "" "ERROR" "$($error[0])"
    }

    CF-Log-To-Master-Log $runEnv.bstr "" "STATUS" "STOP"
}     

Main

