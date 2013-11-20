param (
    [Parameter(mandatory=$true)]
    [string] $backupDirRoot,
    [Parameter(mandatory=$true)]
    [string] $BatchID,
    [bool] $DeleteEachDestDir = $false,
    [int] $dcbPathFoldersToSkip = 0,
    $ignoreStatus = $false,
    $DriverFile,
    $startRow,
    $endRow,
    $writeToDBFile,
    [bool] $JustTestPath = $false
 )

. ((Split-Path $script:MyInvocation.MyCommand.Path) + "/libConversion.ps1")
 
# build full bkup dir path from bkup root + dcb path
# Z:\my-backup-dir + X:\dir1\mydb.dcb => Z:\my-backup-dir\dir1
# inputs: 
#  1) root-path for backupdir
#  2) path-filename of dcb
function Get-BackupDir {
    param ( 
        [string] $backupDirRoot,
        [string] $dcbPfn,
        [int] $numDcbPathFoldersToStrip = 0)
        
    $dcbPfnStub = [system.io.path]::GetDirectoryName($dcbPfn)
    $dcbFile = [system.io.path]::GetFileName($dcbPfn)
    
    # if skip 3 folders:
    # C:\a\b\c\d => c\d
    if ($numDcbPathFoldersToStrip -ne 0) {
       $temp = $dcbPfnStub -split "\\"
       $len = $temp.length
       #write-host "get-backupdir: len = $len "
       $dcbPfnStub =  $temp[$numDcbPathFoldersToStrip .. ($len-1)] -join "\"
    }
    else {
        if ($dcbPfn -match "^.:") {
            $dcbPfnStub = $dcbPfnStub.Substring(3)
        }
        else {
            $dcbPfnStub = $dcbPfnStub.Substring(2)
        }
    }
    $backupDir = "$backupDirRoot\$dcbPfnStub" 
    $conv_dcb = "$backupDir\$dcbFile"
    
    # I dont' know what the heck was going on here, but just couldn't
    # get it to return the hash correctly.  Finally restarted env and 
    # worked better
    #$ret = @{}
    #$ret["backupDir"] = $backupDir
    #$ret["conv_dcb"] = $conv_dcb
    #$ret
    ($backupDir, $conv_dcb)
}
 

# use robocopy to copy the files
## format of robocopy cmd
#  robocopy SrcDir  DestDir [ListOfFileNames]
## robocopy exit codes
# 0 = didn't do anything b/c files already there
# 1 = ran correctly
# > 1  various errors

# return value:  $true if successful, else $false
function Exec-Robocopy {
    param($destDir, $dbfiles)
    
    $success = $false
    # build args array
    ### all dbfiles are in same dir, get the dir name from first entry in list
    $srcDir = [system.io.path]::GetDirectoryName($dbfiles[0])
    $args = @($srcDir, $destDir)
    foreach ($dbfile in $dbfiles) {
        $dbfileName = [system.io.path]::GetFileName($dbfile)
        $args += $dbFileName
    }

    # run robocopy, saving resulting process
    ## flags for Start-Process
    ## -Wait = run synchronously
    ## -PassThru = needed to return the resulting process
    $proc = (start-process robocopy -ArgumentList $args -Wait -NoNewWindow -PassThru)
    if ($proc.ExitCode -gt 1) {
        write-host "Robocopy failed for input dir = $srcDir"
    }
    else {
        $success = $true
    }
    return $success 
}  

# get list of db files on disk (per dcb) and their sizes
# inputs:  1) full-path-to-Dcb
# SPECIAL FOR ARCHIVING
# For main dcb, only get: DCB, INI, KEY, NDX, TEX, DIR, VOL
# Get all of Notes and none of Redlines
function CF-Get-DbFiles-Arch {
    param ( [string] $dcbPfn )
    
    # get name of full pfn without extension
    $dcbBase = CF-Get-PfnWithoutExtension $dcbPfn
    
    # Main files    
    $files = @()
    foreach ($ext in @("DCB", "INI", "KEY", "NDX", "TEX", "DIR", "VOL")) {
        $path = "${dcbBase}.$ext"
        if (test-path $path) {
            $files += get-item $path
        }
    }
    
    # -Notes files (if any)
    $filesTemp = Get-ChildItem "${dcbBase}-notes.*"
    if ($filesTemp) {
        $files += $filesTemp
    }
    
    return $files

}
function Process-Row($dbRow, $runEnv) {
    # Inits
    CF-Init-RunEnv-This-Row $runEnv $dbRow

    try {

        $script:statusFilePFN =  $runEnv.statusFile
        CF-Initialize-Log $script:statusFilePFN
        write-host $script:statusFilePFN
        $script:rowHasError = $false

        $row.$($runEnv.StatusField) = $CF_STATUS_FAILED
        
        $dcbPfn = $row.orig_dcb

        # use backslashes for everything to make it easier
        $dcbPfn = $dcbPfn -replace "/", "\"

        ($backupDir, $row.conv_dcb) = Get-BackupDir $backupDirRoot $dcbPfn $dcbPathFoldersToSkip

        # Delete the destination backup dir? (mostly for testing)
        if (($DeleteEachDestDir) -and (test-path $backupDir)) {
            remove-item -force -recurse $backupDir
        }
        
        # make sure file exists
        if (-not (Test-Path $dcbPfn)) {
            throw "ERROR: can't find dcb[$($runEnv.dbStr)]: $dcbPfn"
            continue
        }
        
        $dbFiles = CF-Get-DbFiles-Arch $dcbPfn
  
        if (-not $dbFiles) {
            write-host "nothing for $dcbPfn"
            continue
        }

        # that scalar / array thing.  If only file, no longer acts like an array
        if ($dbFiles.length -eq 0) { 
            $dbFiles = @($dbFiles)
        }
        
        #foreach ($dbFile in $dbFiles) { write-host "$($dbFile.FullName) : $($dbFile.Length)" }
        if (-not $JustTestPath) {
            $success = Exec-Robocopy  $backupDir $dbFiles
            if ($success = $true) {
                $row.$($runEnv.StatusField) = $CF_STATUS_GOOD
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
    # Initialize
    # Minimum necessary to make entry in master log
    $runEnv = CF-Init-RunEnv $BatchID
    CF-Log-To-Master-Log $runEnv.$bStr "" "STATUS" "START"

    try {
        # Inits
        $script:errMsg = "";
        $bStr = $runEnv.bStr        
        
        # Load driver file, if using
        if ($DriverFile) {
            CF-Load-Driver-File $DriverFile
        }

        # Get dcb names from DB
        $dcbRows = CF-Read-DB-File "DCBs" "BatchID" $BatchID
        
        $backupDirRoot = CF-Get-BackupDirRoot
        $startDate = $(get-date -format $CF_DateFormat)

       # Setup start/stop rows (assume user specifies as 1-based)
        if ($startRow -eq $null) { $startRow = 1 }
        if ($endRow -eq $null) { $endRow = $dcbRows.length } 
        CF-Log-To-Master-Log $runEnv.bstr "" "STATUS" "Start row=$startRow  End row=$endRow"        

        for($i = ($startRow-1) ; $i -lt $endRow ; $i++) {
            $row = $dcbRows[$i]
            $statVal = $row.$($runEnv.StatusField) 
            
            if ($row.batchid -ne $BatchID) {   
                continue
            }

            # Check against driver file, if using
            if ($DriverFile) {
                if (-not (CF-Is-DBID-in-Driver $row.dbid)) {
                    continue
                }
            }

            # Process this row
            Process-Row $row $runEnv

        }
        # Write out whole DB every time in case stop before end of run
        if ($writeToDBFile) {
            CF-Write-DB-File "DCBs" $dcbRows
        }
    }
    catch {
        $error[0] | format-list
        CF-Log-To-Master-Log $runEnv.bstr "" "ERROR" "$($error[0])"
    }

    # Wrap up
    CF-Log-To-Master-Log $runEnv.bstr "" "STATUS" "STOP"
    $endDate = $(get-date -format $CF_DateFormat)
    write-host "*** Done: batch = $BatchID Start row=$startRow  End row=$endRow"
    write-host "Start: $startDate"
    write-host "End:   $endDate"
    if (-not $DriverFile ) { $DriverFile = "None" }
    write-host "Driver file = $DriverFile"

}

Main

