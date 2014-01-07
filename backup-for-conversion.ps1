param (
    [Parameter(mandatory=$true)]
    [string] $BatchID,

    [Parameter(mandatory=$true)]
    [string] $backupDirRoot,

    [switch] $ignoreStatus,
    [switch] $DeleteEachDestDir,
    [int] $dcbPathFoldersToSkip = 0,
    [switch] $FileSetLocalv8,
    [switch] $FileSetConv,
    $DBId,
    $DriverFile,
    $startRow,
    $endRow,
    [switch] $writeToDBFile,
    [switch] $JustTestPath
 )
set-strictmode -version 2


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
    $newDcbPfn = "$backupDir\$dcbFile"
    
    # I dont' know what the heck was going on here, but just couldn't
    # get it to return the hash correctly.  Finally restarted env and 
    # worked better
    #$ret = @{}
    #$ret["backupDir"] = $backupDir
    #$ret["newDcbPfn"] = $newDcbPfn
    #$ret
    ($backupDir, $newDcbPfn)
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
    ### IMPORTANT: all the entries in $myargs have to be in double quotes to handle spaces
    ###            single quotes doesn't work.  
    ###            Can use sysinternals.com ProcMon to see exactly how things are being called
    $srcDir = [system.io.path]::GetDirectoryName($dbfiles[0])
    $myargs = @("""$srcDir""", """$destDir""")
    foreach ($dbfile in $dbfiles) {
        $dbfileName = [system.io.path]::GetFileName($dbfile)
        $myargs += """$dbFileName"""
    }


    # run robocopy, saving resulting process
    ## flags for Start-Process
    ## -Wait = run synchronously
    ## -PassThru = needed to return the resulting process
    $proc = (start-process robocopy -ArgumentList $myargs -Wait -NoNewWindow -PassThru)
    if ($proc.ExitCode -gt 1) {
        write-host "Robocopy failed for input dir = $srcDir"
    }
    else {
        $success = $true
    }
    return $success 
}  

# If any file fails comparison, throws an error for caller to handle.
# Ie, doesn't return normally unless all the files pass comparison
function Verify-Copy-Sizes ($destdir, $dbFiles) {
    foreach ($dbfile in $dbFiles) {
        $dbfileName = [system.io.path]::GetFileName($dbfile)
        $copyPfn = "$destdir\$dbfileName"
        if (!(test-path $copyPfn)) {
            throw "ERROR: file missing: $copyPfn"
        }
        else {
            $copySize = $(get-item $copyPfn).length
            if ($dbFile.length -ne $copySize) {
                throw "ERROR: backup is different size: $copyPfn"
            }
        }
    }
}

function Get-DbFiles-Sizes($dbFiles) {
    $sizes = @()
    foreach ($dbFile in $dbFiles) {
        $size = (get-item $dbFile).length
        $sizes += @($dbFile,$size)
    }
    return $sizes
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

        ($backupDir, $newDcbPfn) = Get-BackupDir $backupDirRoot $dcbPfn $dcbPathFoldersToSkip

        if ($FileSetLocalv8) { $dbrow.local_v8_dcb = $newDcbPfn }
        else { $dbrow.conv_dcb = $newDcbPfn }

        # Delete the destination backup dir? (mostly for testing)
        if (($DeleteEachDestDir) -and (test-path $backupDir)) {
            remove-item -force -recurse $backupDir
        }
        
        # make sure file exists
        if (-not (Test-Path $dcbPfn)) {
            throw "ERROR: can't find dcb[$($runEnv.dbStr)]: $dcbPfn"
            continue
        }
        
        $dbFiles = CF-Get-DbFiles $dcbPfn
  
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
            if ($success -eq $true) {
                # throws error if fails
                Verify-Copy-Sizes $backupDir $dbFiles
                $row.$($runEnv.StatusField) = $CF_STATUS_GOOD
            }
            else {
                throw "ERROR: robocopy failed"
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
    CF-Log-To-Master-Log $runEnv.bStr "" "STATUS" "START"

    try {
        # Inits
        $script:errMsg = "";
        $bStr = $runEnv.bStr        

        if ($FileSetLocalv8 -and $FileSetConv -or ($FileSetLocalv8 -eq $false -and $FileSetConv -eq $false)) {
            write-host "Please choose either -FileSetLocalv8 OR -FileSetConv"
            return
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
            if (CF-Skip-This-Row $runEnv $row @()) {
                continue
            }

            # Process this row
            Process-Row $row $runEnv
            
            # Write out whole DB every time in case stop before end of run
            if ($writeToDBFile) {
                CF-Write-DB-File "DCBs" $dcbRows
            }
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

