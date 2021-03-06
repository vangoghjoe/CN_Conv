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
    $runEnv = CF-Init-RunEnv $BatchID
    CF-Log-To-Master-Log $runEnv.bstr "" "START" "Start row=$startRow  End row=$endRow"
    $startDate = $(get-date -format $CF_DateFormat)

    # Load driver file, if using
    if ($DriverFile) {
        CF-Load-Driver-File $DriverFile
    }

    $dcbRows = CF-Read-DB-File "DCBs" "BatchID" $BatchID

    # Setup start/stop rows (assume user specifies as 1-based)
    if ($startRow -eq $null) { $startRow = 1 }
    if ($endRow -eq $null) { $endRow = $dcbRows.length } 
    CF-Log-To-Master-Log $runEnv.bstr "" "STATUS" "Start CN=$Vstr row=$startRow  End row=$endRow"
     
    # DCB Rows Loop
    for ($i = ($startRow-1) ; $i -lt $endRow ; $i++) {
        $row = $dcbRows[$i]
        
        if ($row.batchid -ne $BatchID) {   
            continue
        }

        # Check against driver file, if using
        if ($DriverFile) {
            if (-not (CF-Is-DBID-in-Driver $row.dbid)) {
                continue
            }
        }

        write-host "$(get-date): $($row.dbid)"
        Process-Row $row $runEnv 
    }

    # Wrap up
    CF-Log-To-Master-Log $runEnv.bstr "" "STATUS" "STOP Start row=$startRow  End row=$endRow"
    $endDate = $(get-date -format $CF_DateFormat)
    write-host "*** Done: batch = $BatchID Start row=$startRow  End row=$endRow"
    write-host "Start: $startDate"
    write-host "End:   $endDate"
    if (-not $DriverFile ) { $DriverFile = "None" }
    write-host "Driver file = $DriverFile"
}     

Main
