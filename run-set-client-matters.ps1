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



function Process-Row {
    param (
        $dbRow,
        $runEnv
    )
    $script:rowHasError = $false
    
    try {
        $bStr = $runEnv.bStr
        $dbid = $dbRow.dbid
        $dcbPfn = $dbRow.conv_dcb
        
        $dbStr = "{0:0000}" -f [int]$dbid
        $dcbDir = [system.io.path]::GetDirectoryName($dcbPfn)
        $inResFile = "${bStr}_${dbStr}_natives.txt"
        $inResFilePFN =  "$($runEnv.SearchResultsDir)\$inResFile"
        $outResFile = "${bStr}_${dbStr}_folders_natives.txt"
        $outResFilePFN =  "$($runEnv.SearchResultsDir)\$outResFile"
        $statusFile = "${bStr}_${dbStr}_folders_natives_STATUS.txt"
        $script:statusFilePFN =  "$($runEnv.ProgramLogsDir)\$statusFile"

        # Initialize output files
        echo $null > $outResFilePFN
        echo $null > $statusFilePFN


        $dirHash = @{}

        # Not sure, but think it may be possible for get-natives to 
        # exit OK but leave no results file if there weren't any natives at all
        # in that case, we want to leave an empty folders file
        echo $null > $outResFilePFN
        if (-not (test-path $inResFilePFN) ) {
            #throw { "Input resfile not found: $inResFilePFN" }
            continue
        }

        # Read contents of natives file to makes list of native folders
        $recs = get-content $inResFilePFN
        foreach ($rec in $recs) {
            try {
                $dirGood = $false
                $dir = [system.io.path]::GetDirectoryName($rec)
                $dirGood = $true
            }
            catch {
                #sometimes the recs are empty
                # but not too common, so only test if error
                if (($rec -ne $null) -and ($rec -ne "")) {
                    write-host "rec = ${rec}"
                    CF-Write-Log $script:statusFilePFN "|ERROR|$($error[0])"
                    $script:rowHasError = $true
                }
            }
            if (($dirGood) -and (-not ($dirHash.Contains($dir)))) {
                $dirHash[$dir]= ""
                CF-Write-File $outResFilePFN $dir
            }
        }
    }
    catch {
        #sometimes the recs are empty
        # but not too common, so rather than testing every time
        if (($rec -ne $null) -and ($rec -ne "")) {
            write-host "rec = x${rec}x"
            CF-Write-Log $script:statusFilePFN "|ERROR|$($error[0])"
            $script:rowHasError = $true
        }
    }
    CF-Finish-Log $script:statusFilePFN 

}   

function Main {
    #CF-Log-To-Master-Log $runEnv.bstr "" "START" "Start row=$startRow  End row=$endRow"
    $startDate = $(get-date -format $CF_DateFormat)

    $dcbRows = CF-Read-DB-File "DCBs" "BatchID" $BatchID
    
    # DCB Rows Loop
    $startRow = 0
    $endRow = $dcbRows.length
    write-host "end = $endRow" # debug
    for ($i = 0 ; $i -lt $endRow ; $i++) {
        $row = $dcbRows[$i]
        $clMtr = CF-Get-Client-Matter $row.orig_dcb
        $row.client_matter = $clMtr
    }
    #$dcbRows
    CF-Write-DB-File "DCBs" $dcbRows

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
