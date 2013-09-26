<#
.SYNOPSIS 

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
    $startRow,
    $endRow
)


. ((Split-Path $script:MyInvocation.MyCommand.Path) + "/libConversion.ps1")

function Load-CM-Dbids($inFile) {
    #for ($i = 0 ; $i -lt $dcbRows.length ; $i++) {
        #$row = $dcbRows[$i]
        #if ($row.batchid -ne "3") { continue }

    $recs = @(get-content $inFile)
    $goodCMs_h = @{}
    foreach ($rec in $recs) {
        ($clMtr, $dbid) = $rec -split "\|"
        if (-not ($goodCMs_h.ContainsKey($clMtr))) {
            $goodCMs_h[$clMtr] = @($dbid)
        }
        else {
            $goodCMs_h[$clMtr] += $dbid
        }
    }
    return $goodCMs_h
}


function Main {
    #CF-Log-To-Master-Log $runEnv.bstr "" "START" "Start row=$startRow  End row=$endRow"
    $startDate = $(get-date -format $CF_DateFormat)


    $sqlCmd = CF-Get-SQL-Cmd $CF_DATA_ARCH_DB


    
    if ($startRow -eq $null) { $startRow = 1 }
    if ($endRow -eq $null) { $endRow = 999999999 }
    $dbRows = CF-Read-DB-File "DCBs"
    foreach ($row in $dbRows) {
        $CMnum++
        if (($CMnum -lt $startRow) -or ($CMnum -gt $endRow)) {
            continue
        }

        write-host "$(get-date): CM = $CM ($CMnum)"

        # Set up dbid vars
        $batchid = $row.batchid
        $dbid = $row.dbid
        $runEnv = CF-Init-RunEnv $batchid
        $clMtr = $row.client_matter
        if ($batchid = 3) { $tba = 1; } else { $tba = 0 }
        write-host "  $(get-date): TBA dbid = $dbid" # DEBUG

        # init filenames
        $bStr = $runEnv.bStr
        $dbStr = "{0:0000}" -f [int]$dbid
        $natives = "${bStr}_${dbStr}_folders_natives.txt"
        $nativesPFN =  "$($runEnv.SearchResultsDir)\$natives"
        $images = "${bStr}_${dbStr}_folders_images.txt"
        $imagesPFN =  "$($runEnv.SearchResultsDir)\$images"

        # add its folders to the hash of TBA folders
        foreach ($srcFile in @($nativesPFN, $imagesPFN)) {
            if ($srcFile -match "native") { $type  = "N"; } else { $type = "I" }

            write-host " src = $srcFile" # DEBUG
            if (test-path $srcFile) {
                $folders = @(get-content $srcFile)
                foreach ($folder in $folders) {
                    $folderUp = $folder.toUpper()
                    # the same folder might be used by more 
                    # than one dbid, but we only need one dbid,
                    # b/c just doing it to QC the process
                    #$TBA_folders_h[$folderUp] = $dbid  
                    $qry = "insert into Folders (dbid, clientmatter, type, tba, folder) "
                    $qry += "values ($dbid, '$clMtr', '$type', $tba, '$folder')"
                    $sqlCmd.CommandText = $qry
                    write-host "   $qry"
                    #$sqlCmd.ExecuteNonQuery()
                }
            }
        }

    } # foreach CM

    write-host "start: $startDate"
    write-host "stop: $(get-date)"
    write-host "startRow: $startRow"
    write-host "endRow: $endRow"
}     

Main


# generate list of client-matters from to-be-archived (TBA) dcbs (Batch 3)
# in batch 4, 
# how tell if a CM is analyzed?
#
# 
# take NA row
#  is it in the bad CM's?  if yes, skip
#  has it passed?  
#    yes - add it to the NA dbid list for it's CM
#    no - delete it's CM from the good CM's; add CM to bad CM's
#
# take a good CM
#   take a dbid
#     add its folders to the hash of folders for that CM
#   take a     
# generate list of folders for TBA in a CM
#  combine images and natives
# generate list of folders for NA in a CM
#  combine images and natives
# for a CM, need list of folders in TBA and list of folders in NA and need to see if any TBA folders are in NA folders
