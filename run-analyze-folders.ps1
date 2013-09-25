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
    $BatchID,
    $DriverFile,
    $startRow,
    $endRow
)


. ((Split-Path $script:MyInvocation.MyCommand.Path) + "/libConversion.ps1")

function Load-CM-Dbids() {
    #for ($i = 0 ; $i -lt $dcbRows.length ; $i++) {
        #$row = $dcbRows[$i]
        #if ($row.batchid -ne "3") { continue }

    $recs = get-content $CF_GOOD_CM_NA_Dbids
    $goodCMs_h = @{}
    foreach ($rec in $recs) {
        ($clMtr, $dbid) = $rec -split "\\"
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

    $dcbRows = CF-Read-DB-File "DCBs" "BatchID" $BatchID

    $CMs_good_run_status_h = Load-CM-Dbids $CF_GOOD_CM_NA_Dbids 
    $batchid = 4 # batch 4 is the Non-archives
    $runEnv = CF-Init-RunEnv $batchid

    # loop over good CM's (from the NA analysis)
    # first build the hash of TBA folders, since typically a smaller list
    # then start going thru the NA folders, looking for collisions
    # if get one, then add to list of client-matters-bad-collision.txt
    # else add to list of client-matters-good-no-collision.txt
    foreach ($CM in $goodCMs_h) {
        #  take a dbid
        foreach ($dbid in $goodCMs_h[$CM]) {
            # init filenames
            $bStr = $runEnv.bStr
            $dbStr = "{0:0000}" -f [int]$dbid
            $searchRe
            $dcbDir = [system.io.path]::GetDirectoryName($dcbPfn)
            $natives = "${bStr}_${dbStr}_folders_natives.txt"
            $nativesPFN =  "$($runEnv.SearchResultsDir)\$natives"
            $images = "${bStr}_${dbStr}_folders_images.txt"
            $imagesPFN =  "$($runEnv.SearchResultsDir)\$images"
            $statusFile = "${bStr}_${dbStr}_analyze_STATUS.txt"
            $script:statusFilePFN =  "$($runEnv.ProgramLogsDir)\$statusFile"

            # add its folders to the hash of folders for that CM


        }
    }
    
    #$dcbRows
    #CF-Write-DB-File "DCBs" $dcbRows

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
