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
function Process-Type($type, $listFile, $missFile, $dbRow) {
    # Inits
    $line = 0
    $numMiss = 0
    $missFile = "${missFile}${type}.txt"
    switch ($type) {
        "natives" {
            $status = $dbRow.st_add_natives
        }
        "images" {
            $status = $dbRow.st_add_images
        }
    }

    # Don't process this type if in progress or already done
    if ($status -gt $CF_STATUS_FAILED) {
        #return
    }
    
    # Make sure not to initialize this until verified not already done!
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
            $dbRow.st_add_natives = $CF_STATUS_GOOD
        }
        "images" {
            $dbRow.images_bytes = $ttlSize
            $dbRow.images_files_present = $numPresent
            $dbRow.images_files_missing = $numMiss
            $dbRow.st_add_images = $CF_STATUS_GOOD
        }
    }
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

    $missFileStub = "${bStr}_${dbStr}_arch_missing_"
    $statusFile = "${bStr}_${dbStr}_check-and-add-sizes_STATUS.txt"
    $missFileStub = "$($runEnv.SearchResultsDir)\$missFileStub"

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
                Process-Type $type $listFilePFN $missFileStub $dbRow
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

