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

    $CMs_NA_h = Load-CM-Dbids $CF_GOOD_CM_NA_Dbids 
    $CMs_TBA = Load-CM-Dbids $CF_CM_TBA_Dbids


    # loop over good CM's (from the NA analysis)
    # first build the hash of TBA folders, since typically a smaller list
    # then start going thru the NA folders, looking for collisions
    # if get one, then add to list of client-matters-bad-collision.txt
    # else add to list of client-matters-good-no-collision.txt

    echo $null > $CF_CM_COLLISIONS
    echo $null > $CF_CM_NO_COLLISIONS
    
    $CMnum = 0
    if ($startRow -eq $null) { $startRow = 0 }
    if ($endRow -eq $null) { $endRow = 999999999 }
    foreach ($CM in $CMs_NA_h.keys) {
        $CMnum++
        if (($CMnum < $startRow) -or ($CMnum>$endRow) {
            continue
        }

        $has_collision = $false
        write-host "$(get-date): CM = $CM ($CMnum)"

        #  loop over TBA dbids for this CM
        $batchid = 3 # batch 3 is the TBAs
        $runEnv = CF-Init-RunEnv $batchid
        $TBA_folders_h = @{}
        foreach ($dbid in $CMs_TBA[$CM]) {
            write-host "  $(get-date): TBA dbid = $dbid"
            # init filenames
            $bStr = $runEnv.bStr
            $dbStr = "{0:0000}" -f [int]$dbid
            #$dcbDir = [system.io.path]::GetDirectoryName($dcbPfn)
            $natives = "${bStr}_${dbStr}_folders_natives.txt"
            $nativesPFN =  "$($runEnv.SearchResultsDir)\$natives"
            $images = "${bStr}_${dbStr}_folders_images.txt"
            $imagesPFN =  "$($runEnv.SearchResultsDir)\$images"

            # add its folders to the hash of TBA folders
            foreach ($srcFile in @($nativesPFN, $imagesPFN)) {
                if (test-path $srcFile) {
                    $folders = @(get-content $srcFile)
                    foreach ($folder in $folders) {
                        $folderUp = $folder.toUpper()
                        # the same folder might be used by more 
                        # than one dbid, but we only need one dbid,
                        # b/c just doing it to QC the process
                        $TBA_folders_h[$folderUp] = $dbid  
                    }
                }
            }
        }

        #  loop over NA dbids for this CM
        $batchid = 4 # batch 4 is the NAs
        $runEnv = CF-Init-RunEnv $batchid
        foreach ($dbid in $CMs_NA_h[$CM]) {
            write-host "  $(get-date): NA dbid = $dbid"
            # init filenames
            $bStr = $runEnv.bStr
            $dbStr = "{0:0000}" -f [int]$dbid
            #$dcbDir = [system.io.path]::GetDirectoryName($dcbPfn)
            $natives = "${bStr}_${dbStr}_folders_natives.txt"
            $nativesPFN =  "$($runEnv.SearchResultsDir)\$natives"
            $images = "${bStr}_${dbStr}_folders_images.txt"
            $imagesPFN =  "$($runEnv.SearchResultsDir)\$images"

            # loop over all NA folders in this CM to test for collision
            foreach ($srcFile in @($nativesPFN, $imagesPFN)) {
                if (test-path $srcFile) {
                    $folders = @(get-content $srcFile)
                    foreach ($folder in $folders) {
                        $folderUp = $folder.toUpper()

                        # OK, can finally do the collision check
                        if ($TBA_folders_h.ContainsKey($folderUp)) {
                            $has_collision = $true
                            $m = "$CM|TBA ID: $($TBA_folders_h[$folderUp])"
                            $m += "|NA ID: $dbid"
                            $m += "|$folder"
                            CF-Write-File $CF_CM_COLLISIONS $m
                            write-host "  $(get-date): Collision"
                            write-host "  $(get-date): $m"
                            break
                        }
                    } #folder
                } # test-path $srcFile
                if ($has_collision) { break }
            } # foreach srcFile
            if ($has_collision) { break }
        } # foreach dbid in CMs_NA

        if (-not ($has_collision)) {
            CF-Write-File $CF_CM_NO_COLLISIONS "$CM"
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
