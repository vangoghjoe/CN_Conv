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


function Process-Vol($volPfn) {

    # would be faster with arrays, but don't have time to fuss with it
    $script:volPaths = @{}

    # Force array context in case file only has one line
    $recs = @(get-content $volPfn)  # need this to work if file only has one line
    foreach ($rec in $recs) {
        $gotIt = $true
        $rec = $rec.Trim()
        # some recs may be corrupted.  that's ok, just move on and
        # try to get the best we can.  We'll parse both formats
        # in case the key/path we need is in only one of them.
        # And we'll rely on the key look ups in the Image section
        # to help and then the search for the file on the filesystem
        # in other code to make sure have good values

        #try {
        # if the rec starts with a path, parse it one way
        if (CF-IsPath $rec) {
            ($path, [int]$key) = $rec -split "\|"
        }
        # otherwise, its in the 2nd format.  
        else {
            ([int]$key, $vol, $path, $keyNum) = $rec -split "\|"
         }
        #}
        #catch {
            ## note it in the status file, but don't consider it an error
            #CF-Write-Log $script:statusFilePFN "Warning parsing VOL file: $($error[0])"
            #$gotIt = $false
        #}
        if ($gotIt) {
            $path = $path.Trim()  
            
            # check for conflicts
            if ($script:volPaths.containsKey($key)) {
                if ($script:volPaths[$key] -ne $path) {
                    throw "ERROR: Different paths for key '$key'"
                }
            }
            $script:volPaths[$key] = $path
        }
    }
}

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
        $inResFile = "${bStr}_${dbStr}_images_VOL.txt"
        $inResFilePFN =  "$($runEnv.SearchResultsDir)\$inResFile"
        $outResFile = "${bStr}_${dbStr}_folders_images.txt"
        $outResFilePFN =  "$($runEnv.SearchResultsDir)\$outResFile"
        $statusFile = "${bStr}_${dbStr}_folders_images_STATUS.txt"
        $script:statusFilePFN =  "$($runEnv.ProgramLogsDir)\$statusFile"

        # Initialize output files
        echo $null > $outResFilePFN
        echo $null > $statusFilePFN



        # Not sure, but think it may be possible for get-natives to 
        # exit OK but leave no results file if there weren't any natives at all
        # in that case, we want to leave an empty folders file
        echo $null > $outResFilePFN
        if (-not (test-path $inResFilePFN) ) {
            #throw { "Input resfile not found: $inResFilePFN" }
            continue
        }

        # Get Volumes
        $script:volPaths = @{}
        Process-Vol $inResFilePFN
        foreach ($value in $script:volPaths.values) {
            $dir = CF-Strip-Last-Slash($value.toUpper())
            CF-Write-File $outResFilePFN $dir
        }
    }
    catch {
        #sometimes the recs are empty
        # but not too common, so rather than testing every time
        write-host "rec = x${rec}x"
        CF-Write-Log $script:statusFilePFN "|ERROR|$($error[0])"
        $script:rowHasError = $true
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
