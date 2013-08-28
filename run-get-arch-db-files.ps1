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
    [switch] $ignoreStatus 
)


. ((Split-Path $script:MyInvocation.MyCommand.Path) + "/libConversion.ps1")


# takes a dcbPfn and returns its files, including everything in the "logs" dir
function Get-DbFiles {
    param ( [string] $dcbPfn )
    
    # get name of full pfn without extension
    $dcbBase = CF-Get-PfnWithoutExtension $dcbPfn
    if (-not (test-path $dcbPfn)) {
        throw "DCB doesn't exist: $dcbPfn"
    }

    $logsDir = [system.io.path]::GetDirectoryName($dcbPfn) + "\logs"
    
    # not sure what files we should get for this:
    # 1) just the DB files, including the logs dir
    # 2) just the DB files and logs dir, but minus the DCT, IVT and FZY?
    # 3) any files in this dir, plus the logs dir
    # 4) everything in this dir, including sub folders 
    #
    # 3 and 4 will be a little more work to avoid double counting.  (Sure, could
    # get double counting for the logs dir for #1 and #2, but that's small)
    #
    # For now, go with #1
    $files = Get-ChildItem "${dcbBase}.*","${dcbBase}-notes.*","${dcbBase}-redlines.*"
    if (test-path $logsDir) {
       $files += Get-ChildItem $logsDir
    }
    return $files
}

function Process-Row($dbRow, $runEnv) {

    # Setup paths
    $bStr = $runEnv.bStr
    $dbid = $dbRow.dbid
    
    # CAREFUL: have to use ORIG DCB for this one, since only backed up the db files
    $dcbPfn = $dbRow.orig_dcb;
    
    $dbStr = "{0:0000}" -f [int]$dbid
    # just one output file, holds all the valid db folders
    $resFile = "${bStr}_db_folders.txt"
    $statusFile = "${bStr}_${dbStr}_get_arch_db_files_STATUS.txt"
    $resFilePFN = "$($runEnv.SearchResultsDir)\$resFile"
    $script:statusFilePFN =  "$($runEnv.ProgramLogsDir)\$statusFile"
    write-host $script:statusFilePFN

    # Init logs
    CF-Initialize-Log $script:statusFilePFN
    CF-Initialize-Log $resFilePFN 
    
    # Get the db files and write them to the result file
    $script:rowHasError = $false
    try {
        $files | out-file -append -encoding ASCII -filepath $resFilePFN
    }
    catch {
        $script:rowHasError = $true
        CF-Write-Log $script:statusFilePFN "|ERROR|$($error[0])"
    }

    # Wrap up this row
    CF-Finish-Log $script:statusFilePFN 
}

# for each dcb, just make sure the dcb is actually present
# if so, add to the file of list of db-folders
# and add up it's size and file count
function Main {
    $statusFld = "st_get_arch_db_files"
    $runEnv = CF-Init-RunEnv $BatchID
    CF-Log-To-Master-Log $runEnv.bstr "" "STATUS" "START"

    try {
        $dcbRows = CF-Read-DB-File "DCBs" 

        for($i = 0 ; $i -lt $dcbRows.length; $i++) {
            $row = $dcbRows[$i]
            #write-host ($i+1 + " of " + $dcbRows.length + ": " + $row.dbid)
            
            # Only process this row if it's in the right batch 
            # and has the right status
            if ($row.batchid -ne $BatchID) {
                continue
            }
            #if (($row.$statusFld -eq $CF_STATUS_IN_PROGRESS) -or
                #($ignoreStatus=$false -and ($row.$statusFld -eq $CF_STATUS_GOOD))) {
                #continue
            #}

            write-host ("in batch: " + $row.orig_dcb)
            
            if ($row.backup_done -lt 1) {
                continue
            }

            write-host ("good statusn" + $row.orig_dcb)
            $dcbPfn = $row.orig_dcb
            $dcbDir = [system.io.path]::GetDirectoryName($dcbPfn) 
            CF-Write-File $dcbDir "list-of-dcb-dirs-for-bckup.txt"
            

        }

        # Finished with all the rows.  Rewrite the whole DB file
        #CF-Write-DB-File "DCBs" $dcbRows
    }
    catch {
        CF-Log-To-Master-Log $runEnv.bstr "" "ERROR" "$($error[0])"
    }

    # Log end of pgm to master log
    CF-Log-To-Master-Log $runEnv.bstr "" "STATUS" "STOP"
}     

Main


