param (
    [string] $backupDirRoot,
    [string] $BatchID,
    [bool] $DeleteEachDestDir = $false,
    [int] $dcbPathFoldersToSkip = 0
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
function Exec-Robocopy {
    param($destDir, $dbfiles)
    
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
    if ($proc.ExitCode > 1) {
        write-host "Robocopy failed for input dir = $srcDir"
    }
}  
 
function Main {
    # Initialize
    $runEnv = CF-Init-RunEnv $BatchID
    CF-Log-To-Master-Log $runEnv.$bStr "" "STATUS" "START"

    $script:errMsg = "";
    $bStr = $runEnv.bStr        
    
    $backupDirRoot = CF-Get-BackupDirRoot
    get-date -format g

    # Get dcb names from DB
    $dcbRows = CF-Read-DB-File "DCBs" "BatchID" $BatchID
    
    for($i = 0 ; $i -lt $dcbRows.length; $i++) {
        $row = $dcbRows[$i]
        
        if ($row.batchid -ne $BatchID) {   
            continue
        }

        $dcbPfn = $row.orig_dcb
        write-host $dcbPfn

        # use backslashes for everything to make it easier
        $dcbPfn = $dcbPfn -replace "/", "\"

        #$retHash = Get-BackupDir $backupDirRoot $dcbPfn $dcbPathFoldersToSkip
        #$backupDir = $retHash["backupDir"]
        #$row.conv_dcb =  $retHash["conv_dcb"]
        ($backupDir, $row.conv_dcb) = Get-BackupDir $backupDirRoot $dcbPfn $dcbPathFoldersToSkip
        
        # Delete the destination backup dir? (mostly for testing)
        if (($DeleteEachDestDir) -and (test-path $backupDir)) {
            remove-item -force -recurse $backupDir
        }
        
        # make sure file exists
        if (-not (Test-Path $dcbPfn)) {
            write "ERROR: can't find dcb: $dcbPfn"
            continue
        }
        
        $dbFiles = CF-Get-DbFiles $dcbPfn
  
        if (-not $dbFiles) {
            write-host "nothing for $dcbPfn"
            continue
        }
        
        #foreach ($dbFile in $dbFiles) { write-host "$($dbFile.FullName) : $($dbFile.Length)" }
        Exec-Robocopy  $backupDir $dbFiles
        $dcbRows[$i] = $row
    }
    CF-Write-DB-File "DCBs" $dcbRows
    get-date -format g
}

Main

