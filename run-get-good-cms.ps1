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


function Row-Has-Been-Analyzed ($row) {
    if (($row.st_get_natives -eq 2) -and
        ($row.st_get_images -eq 2) -and
        ($row.st_get_folders_natives -eq 2) -and
        ($row.st_get_folders_images -eq 2)) {
        return $true
    }
    else {
        return $false
    }
}

function Load-TBA-CMs($dcbRows) {
    #for ($i = 0 ; $i -lt $dcbRows.length ; $i++) {
        #$row = $dcbRows[$i]
        #if ($row.batchid -ne "3") { continue }

    $tbaCMsFile = "Data Archiving/client-matters-TBA.txt"
    $CMs = get-content $tbaCMsFile
    $h = @{}
    foreach ($CM in $CMs) { $h[$CM] = "" }
    return $h
}

function Write-Out-Bad-CMs($badCMs_h) {
    echo $null > $CF_BAD_CMs
    foreach ($CM in $badCMs_h.keys) {
        CF-Write-File $CF_BAD_CMs $CM
    }
}

function Write-Out-Good-CMs($goodCMs_h) {
    echo $null > $CF_GOOD_CMs
    foreach ($CM in $goodCMs_h.keys) {
        foreach ($dbid in $goodCMs_h[$CM]) {
            CF-Write-File $CF_GOOD_CMs "$CM|$dbid"
        }
    }
}

function Main {
    #CF-Log-To-Master-Log $runEnv.bstr "" "START" "Start row=$startRow  End row=$endRow"
    $startDate = $(get-date -format $CF_DateFormat)

    $dcbRows = CF-Read-DB-File "DCBs" "BatchID" $BatchID

    #$tbaCM = Load-TBA-CMs $dcbRows
    $tbaCM = Load-TBA-CMs
    
    $badCMs_h = @{}
    $goodCMs_h = @{}
    
    # DCB Rows Loop
    $startRow = 0
    $endRow = $dcbRows.length
    write-host "end = $endRow" # debug
    for ($i = 0 ; $i -lt $endRow ; $i++) {
        $row = $dcbRows[$i]
        $dbid = $row.dbid
        $clMtr = CF-Get-Client-Matter $row.orig_dcb

        # take NA row ( batchid = 4 )
        if ($row.batchid -ne "4") { continue }

        # is it a TBA CM?
        if (-not ($tbaCM.ContainsKey($clMtr))) { continue }
        #  is it in the bad CM's?  if yes, skip
        if ($badCMs_h.ContainsKey($clMtr)) { continue }
        #  has it passed?  
        if (Row-Has-Been-Analyzed($row)) {
        #    yes - add it to the NA dbid list for it's CM
            if (-not ($goodCMs_h.ContainsKey($clMtr))) {
                $goodCMs_h[$clMtr] = @($dbid)
            }
            else {
                $goodCMs_h[$clMtr] += $dbid
            }
        }
        #    no - delete it's CM from the good CM's; add CM to bad CM's
        else {
            $goodCMs_h.remove($clMtr)
            $badCMs_h[$clMtr] = ""
        }
    }

    Write-Out-Bad-CMs $badCMs_h
    Write-Out-Good-CMs $goodCMs_h

        # take a good CM
        #   take a dbid
        #     add its folders to the hash of folders for that CM
        #   take a     


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
