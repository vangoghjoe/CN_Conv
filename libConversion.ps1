#####
$CF_DEBUG = $true
#####

. ((Split-Path $script:MyInvocation.MyCommand.Path) + "/conversion-config.ps1")

$CF_DATA_ARCH_DB = "Hogan_Data_Archiving"


$CF_ConvAdminDir = "$CF_LNRoot\Conversion_Admin"
$CF_DBDir = "$CF_ConvAdminDir\DB"
$CF_BatchesDir = "$CF_ConvAdminDir\Batches"
$CF_ScriptDir = "$CF_LNRoot\Scripts"

$CF_LocalConvDir = "_LN-Conversion"

$CF_DBName = "FYI_Conversions"

$CF_DateFormat = "yyyy-MM-dd HH:mm:ss"

$script:CF_BatchEnv = @{}  # Environment for whole batch
$script:CF_DBEnv = @{}  # DB-specifc environment

$CF_CPL_SPACE_STRING = "LN_SPACE_XYZ" ; # replace spaces in path for use in CPL's

$CF_BAD_CM_NA_Dbids = "Data Archiving/client-matters-bad-NA-with-dbids.txt"
$CF_GOOD_CM_NA_Dbids = "Data Archiving/client-matters-good-NA-with-dbids.txt"
$CF_CM_TBA_Dbids = "Data Archiving/client-matters-TBA-with-dbids.txt"
$CF_CM_COLLISIONS = "Data Archiving/client-matters-bad-collisions.txt"
$CF_CM_NO_COLLISIONS = "Data Archiving/client-matters-good-no-collisions.txt"

$CF_PGMS = @{
# 0 = status field
# 1 = root for status file
# 2 = root search results (can be array)
# 3 = prev pgm(s) it depends on (pipe delimited list)
"backup-for-archiving" = @("st_backup_arch", "backup-for-archiving");
"backup-for-conversion" = @("st_backup", "backup-for-conversion");
"run-qc-v8-tags" = @("st_qc_v8_tags", "v8_tagging", "backup-for-conversions");
"run-qc-list-dict-v8" = @("st_qc_list_dict_v8", "qc-list-dict-v8", "backup-for-conversions");
"run-qc-dict-pick-qc-words" = @("st_qc_dict_pick_qc_words", "qc-dict-pick-qc-words", "backup-for-conversions");
"run-qc-query-dict-v8" = @("st_qc_query_dict_v8", "qc-query-dict-v8", "backup-for-conversions");
"run-convert-one-dcb" = @("st_convert_one_dcb", "convert-one-dcb", "run-qc-v8-tags|run-qc-v8-dict");
"run-qc-v10-tags" = @("st_qc_v10_tags", "v10_tagging", "backup-for-conversions");
"run-qc-list-dict-v10" = @("st_qc_list_dict_v10", "qc-list-dict-v10", "backup-for-conversions");
"run-qc-query-dict-v10" = @("st_qc_query_dict_v10", "qc-query-dict-v10", "backup-for-conversions");
"run-qc-compare-tags" = @("st_qc_compare_tags", "qc-compare-tags", "run-qc-v8-tags|run-qc-v10-tags");
"run-qc-compare-dict" = @("st_qc_compare_dict", "qc-compare-dict", "run-qc-query-dict-v8|run-qc-query-v10");
"run-get-images" = @("st_get_images", "images", "backup-for-archiving");
"run-get-images-pt2" = @("st_get_images2","images_pt2","images_ALL", "run-get-images");
"run-get-natives" = @("st_get_natives","natives","natives","backup-for-archiving");
"run-get-natives-folders" = @("st_get_folders_natives","folders_natives","folders_natives","");
"run-get-images-folders" = @("st_get_folders_images","folders_images","folders_images","");
"run-get-sizes" = @("st_get_sizes","get-sizes");
# run-check is a bit problematic: runs as one pgm, but in terms of outputs, its easier 
# to treat as two separate ones.  
"run-check-and-add-sizes-to-file-natives" = @("st_sizes_natives","sizes_natives","sizes_natives");
"run-check-and-add-sizes-to-file-images" = @("st_sizes_images","sizes_images","sizes_images");
"run-get-db-sizes" = @("st_db_sizes")
}

$CF_FIELDS = @(
"batchid",
"dbid",
"clientid",
"loadnr",
"orig_dcb",
"conv_dcb",
"orig_dir",
"backup_done",
"db_bytes",
"db_files",
"natives_bytes",
"natives_files_present",
"natives_files_missing",
"images_bytes",
"images_files_present",
"image_files_missing",
"st_backup",
"st_get_images",
"st_get_images2",
"st_get_natives",
"st_qc_v8_tags",
"st_qc_v10_tags",
"st_qc_compare_tags",
"st_backup_arch",
"st_convert",
"st_get_arch_db_files",
"funky",
"st_add_images",
"st_add_natives",
"st_add_db"
)

$CF_STATUS_FAILED = -1
$CF_STATUS_READY = 0  # as in, ready to be processed
$CF_STATUS_IN_PROGRESS = 1
$CF_STATUS_GOOD = 2

function CF-Put-DCB-Header-On-Clipboard() {
    # intended to be redirected to a file
    [Windows.Forms.Clipboard]::SetText($CF_FIELDS -join "`t")
}

function CF-Load-Driver-File($driverPFN, $pieceNum = 0) {
   $script:driverIDs = @{}

   $recs = get-content $driverPFN
   foreach ($rec in $recs) {
        $p = $rec -split "\|"
        $script:driverIDs[$p[$pieceNum]] = ""
   }
}

function CF-Is-DBID-in-Driver ($dbid) {
    return $script:driverIDs.ContainsKey($dbid)
}

### Given a dir, returns @($bytes, $numFiles), where
#  $bytes =    total size of all files in the dir and any subdirs
#  $numFiles = num files  " " "
# If folder doesn't exists, returns @("", "")
function CF-Get-Num-Files-And-Size-Of-Folder ($dir) {
    if (test-path $dir) {
        $size = $numFiles = 0
        Get-ChildItem -Recurse $dir | foreach {
            if (-not ($_.PSIsContainer)) { $size+= $_.length ; $numFiles++ }
        }
    }
    else {
        $size = $numFiles = ""
    }
    
    return @($size, $numFiles)
}


function CF-Check-DB-Fields($dbRows) {
}
    
function CF-Init-RunEnv-This-Row ($runEnv, $dbRow) {
    $dbid = $dbRow.dbid
    $bStr = $runEnv.bStr
    $dbStr = "{0:0000}" -f [int]$dbid
    $runEnv["dbStr"] = $dbStr
    
    if ($runEnv.ContainsKey('outFileStub')) {
        $statusFile = "${bStr}_${dbStr}_$($runEnv.outFileStub)_STATUS.txt"
        $runEnv["StatusFile"] =  "$($runEnv.ProgramLogsDir)\$statusFile"
    }
    $runEnv["badbStr"] = "${bstr}_${dbStr}"
}

function CF-Init-RunEnv-This-Row2 ($runEnv, $dbRow) {
    $dbid = $dbRow.dbid
    $bStr = $runEnv.bStr
    $dbStr = "{0:0000}" -f [int]$dbid
    $runEnv["dbStr"] = $dbStr
    $runEnv["badbStr"] = "${bstr}_${dbStr}"
    
    $statusFilePFN = "${bStr}_${dbStr}_$($runEnv.outFileStub)_STATUS.txt"
    $runEnv["StatusFilePFN"] =  "$($runEnv.ProgramLogsDir)\$statusFilePFN"
    
    $resFilePFN = "${bStr}_${dbStr}_$($runEnv.outFileStub).txt"
    $runEnv["ResFilePFN"] =  "$($runEnv.SearchResultsDir)\$resFilePFN"
    return ($runEnv.StatusFilePFN, $runEnv.resFilePFN)
}

function CF-Init-RunEnv {
    param  (
        $bID,
        $Vstr
    )
    
    $bStr = "{0:000.0}" -f [float]$bID
    $h = @{}

    # first calc directories that will be created
    $h["BatchDir"] = "$CF_BatchesDir\$bStr"
    $h["LogsDir"] = "$($h.BatchDir)\Logs"
    $h["QCResultsDir"] = "$($h.LogsDir)\QC_Results"
    $h["SearchResultsDir"] = "$($h.LogsDir)\Search_Results"
    $h["ProgramLogsDir"] = "$($h.LogsDir)\Program_Logs"
    
    # make the dirs
    foreach ($enum in $h.GetEnumerator()) {
        if (-not (test-path $enum.value)) {
            #write $enum.value
            mkdir -p $enum.value # > $null # don't want to write to screen
        }
    }

    # lastly, add in any values that aren't for dirs to be made
    $h["bID"] = $bID
    $h["bStr"] = $bStr
    $h["MasterLogPFN"] = "$($h.LogsDir)\_Master.log"
    $basename = [system.io.path]::GetFileNameWithoutExtension($script:MyInvocation.MyCommand.Path)

    # the pgm run-qc-tags is a special case b/c runs in both v8 and v10 mode
    if ($basename -eq 'run-qc-tags') {
        $basename = "run-qc-${Vstr}-tags"
    }
    elseif ($basename -eq 'run-qc-list-dict' -or ($basename -eq 'run-qc-query-dict')) {
        $basename = "${basename}-${Vstr}"
    }
    $h["BaseName"] = $basename 

    # get outStub and status field
    if ($CF_PGMS.ContainsKey($basename)) {
        $h["StatusField"] = $CF_PGMS[$basename][0]
        $h["outFileStub"] = $CF_PGMS[$basename][1]
    }
    #else {
        #$h.Remove("StatusField")
        #$h.Remove("outFileStub")
    #}
    else {
        $h["StatusField"] = "st_" + $basename.replace("^run-","").replace("-","_")
        $h["outFileStub"] = "st_" + $basename.replace("^run-","")
    }
        
    
    $script:CF_BatchEnv = $h
    return $h
    
}

# Given name of a program, returns
# @($statusField, 
function CF-Get-Pgm-Global-Config ($pgmName) {
    # get outStub and status field
    $h = @{} 
    if ($CF_PGMS.ContainsKey($pgmName)) {
        $h["StatusField"] = $CF_PGMS[$pgmName][0]
        $h["outFileStub"] = $CF_PGMS[$pgmName][1]
    }
    else {
        $h["StatusField"] = "st_" + $pgmName.replace("^run-","").replace("-","_")
        $h["outFileStub"] = "st_" + $pgmName.replace("^run-","")
    }
    return $h
}


# sets a script level var to hold the current logPfn
function CF-Initialize-Log ($logPfn) {
    if (test-path $logPfn) {
        clear-content $logPfn
    }
}

# Takes a status file, pulls out any errors,
# adds some info to each error, and appends it to the global err log
function CF-Make-Global-Error-File-Record ($pgm, $dbRow, $pgmStatusFilePFN, $errLog, $forBlankStatus = $false) {
    if ($forBlankStatus) {
        $msg = @($dbRow.dbid, $dbRow.clientid, $pgm, $dbRow.orig_dcb, "") -join "|"
        $msg += ("| BLANK STATUS FIELD")
    }
    else {
        $recs = @(get-content $pgmStatusFilePFN)
        $buf = ""

        # Error recs look like:
        # 2013-08-30 20:21:50||ERROR|The jabberwocky is in the house
        #
        # Not sure if there can be more than one error in a given STAT file, but will assume there can be
        # Will make each it's own rec in the this global error log
        #
        # Output err struc:
        # dbid | clientid | pgm | orig_dcb | TS | any other pieces 
        foreach ($rec in $recs) {
            $p = $rec -split "\|"
            if ($p[2] -eq "ERROR") {
                $msg = @($dbRow.dbid, $dbRow.clientid, $pgm, $dbRow.orig_dcb, $p[0]) -join "|"
                $msg += ("|" + $p[3 .. ($p.length-1)] -join "|")
                CF-Write-File $errLog $msg
            }
        }
    }
    #CF-Write-File $errLog $msg
}

# adds some info to each error, and appends it to the pgm's good log
# pgm | dbid | clientid | orig_dcb | TS
# pgm | dbid | clientid | orig_dcb | TS
# dbid | clientid | pgm | orig_dcb | TS 
function CF-Make-Global-Good-File-Record ($pgm, $dbRow, $pgmStatusFilePFN, $goodlog) {
    $recs = @(get-content $pgmStatusFilePFN)
    if ($recs.length) {
        $lastLine = $recs[-1]
        $p = $lastLine -split "\|"
        $TS = $p[0]
    }
    else {
        $TS = "00:00:00"
    }

    $msg = @( $dbRow.dbid, $dbRow.clientid, $pgm, $dbRow.orig_dcb, $TS) -join "|"
    CF-Write-File $goodlog $msg
}

function CF-Resolve-Error ($ErrorRecord=$Error[0])
{
   $ErrorRecord | Format-List * -Force
   $ErrorRecord.InvocationInfo |Format-List *
   $Exception = $ErrorRecord.Exception
   for ($i = 0; $Exception; $i++, ($Exception = $Exception.InnerException))
   {   "$i" * 80
       $Exception |Format-List * -Force
   }
}


function CF-Write-Log ($logPfn, $msg) {
    if ($msg -match "error") { 
        write-host ("Write to error log: " + $msg )
        if ($CF_DEBUG) {
            $error[0] | format-list
        }
    }

    $msg = "$(get-date -format $CF_DateFormat)|$msg"
    $msg | out-file -encoding ASCII -append -filepath $logPfn
}

# Simply appends a line to a file (badly named)
function CF-Write-File($file, $msg) {
    $msg | out-file -encoding ASCII -append -filepath $file
}

function CF-Finish-Log ($logPfn) {
    CF-Write-Log $logPfn "|STOP|"
    if ($script:rowHasError) {
        CF-Write-Log $logPfn "|EXIT_STATUS|FAILED" 
    }
    else {
        CF-Write-Log $logPfn "|EXIT_STATUS|OK"
    }
}

function CF-Finish-Results-Log ($logPfn) {
    CF-Write-Log $logPfn "|STOP|"
    if ($script:rowResultsHasError) {
        CF-Write-Log $logPfn "|EXIT_STATUS|FAILED" 
    }
    else {
        CF-Write-Log $logPfn "|EXIT_STATUS|OK"
    }
}


function CF-IsPath ($str) {
    (($str -match "^\\\\") -or ($str -match "^[A-z]:"))
}



function CF-Log-Says-Ran-Successfully ($logPFN) {
    if (Test-Path $logPFN) {
        $logRecs = @(get-content $logPfn)
        if ($logRecs.length) {
            $lastLine = $logRecs[$logRecs.length - 1]
            if ($lastLine -match "EXIT STATUS|OK") {
                return $true;
            }
            else {
                return $false;
            }
        }
        else {
            # empty file => failed
            return $false;
        }
    }
    else {
        return $false;
    }
}
        


function CF-Make-DbStr ([int] $dbid) {
    return "{0:0000}" -f [int]$dbid
}

# $type = status or search or qc
function CF-Make-Output-PFN-Name ($runEnv, $stub, $type) {
    if ($type -eq "status") { 
        $root = $runEnv.ProgramLogsDir 
        $suf = "_STATUS" 
    } 
    elseif ($type -eq "search") { 
        $root = $runEnv.SearchResultsDir 
        $suf = "" 
    } 
    $file = $root + "\" + $runEnv.badbStr + "_" + $stub + $suf + ".txt"
    return $file
}

function CF-Log-To-Master-Log {
    # typically will call this at the beginning of a session and store
    # then use it whenever logging to Master Log
    
    # Every rec will start with:
    #  TS | HOST | PID | PGM | USER | BATCH | DBID
    param (
        $bStr,
        $dbStr,
        $type,      # INFO, ERROR, STATUS
        $msg
    )
 
    $pgm = [system.io.path]::GetFileNameWithoutExtension($script:MyInvocation.MyCommand.Path)
    
    # TS | HOST | PID | PGM | USER | BATCH | DBID
    $x = @( $(get-date -format $CF_DateFormat), $(hostname), $pid, $pgm, [Environment]::Username, 
            $bStr, $dbStr, $type, $msg)
    $x -join '|' | out-file -append -encoding ASCII $script:CF_BatchEnv.MasterLogPFN
       
}

# Takes a list of orig DCB's and a batch number
#

# DCB-DB.txt
#  
function CF-Init-Batch {
    # ok for now, have to copy the DCB's into the orig-dcb header of the TSV
}

# returns variable pointing to all rows
function CF-Read-DB-File ($table, $searchName, $p1, $p2, $p3) {

    # TODO: lock file first
    $dbFile = "$CF_DBDir\${table}.txt"
    $lockFile = "$dbFile.LOCK"
    
    # spin until 
    try {
        copy -force $dbFile "${dbfile}.$(get-date -Format "yyyyMMdd.HHmmss").txt"
        $rows = import-csv -ErrorAction Stop -Delimiter "`t" $dbFile
    }
    catch {
        write-host "$($error[0])"
        exit
    }
    
    # TODO: unlock file
    return $rows
}

# up to caller to catch errors
function CF-Write-DB-File ($table, $rows) {
    # TODO: lock file first
    $dbFile = "$CF_DBDir\${table}.txt"
    
    $rows | export-csv -Delimiter "`t" $dbFile

    # TODO: unlock file

}

function CF-Append-To-Logs {
    param (
        [string] $msg,
        [string] $dcbPfn
    )
    
    
    # make localDir if it doesn't exist
    #CF-Make-Local-Conv-Dir ($
    
}    

#function CF-Add-To-Record ($rec, $

function CF-Encode-CPL-Safe-Path {
    param (
        $path
    )
    return $path.replace(" ", $CF_CPL_SPACE_STRING)
}
        
function CF-Decode-CPL-Safe-Path {
    param (
        $path
    )
    return $path.replace($CF_CPL_SPACE_STRING, " ")
}
        
function CF-Make-Local-Conv-Dir {
    param (
        [string] $dcbPfn
    )
    if (-not (Test-Path $localDir)) {
        try {
            mkdir -p $localDir
        }
        catch [system.exception] {
            Write-Host "[ERROR]: Can't create local log dir ($localDir): " + $_.Exception.ToString()
            exit
        }
    }
}    

# init some common vars, such as those based on $dcbPfn
function CF-Init-Vars {
    param (
        [string] $dcbPfn
    )
    $script:localConvDir = [system.io.path]::GetDirectoryName($dcbPfn) + "\$CF_LocalConvDir"
    $script:localConvLog = "$localDir\log.txt"

}

# get list of dcbs
function CF-Get-DcbList {
    $dcbList = Get-Content $fileOfListOfDcbs
    return $dcbList
}

# get name of bkup dir
function CF-Get-BackupDirRoot { return $backupDirRoot }



# Given a full path-filename, returns that same path-filename, but without the extension
# inputs: path-filename
function CF-Get-PfnWithoutExtension {
    param($pfn)
    $parent =  Split-Path -Parent $pfn
    $basename = [system.io.path]::GetFileNameWithoutExtension($pfn)
    return join-path -path $parent -childpath $basename
}

# get list of db files on disk (per dcb) and their sizes
# inputs:  1) full-path-to-Dcb
function CF-Get-DbFiles {
    param ( [string] $dcbPfn )
    
    # get name of full pfn without extension
    $dcbBase = CF-Get-PfnWithoutExtension $dcbPfn
    
    return Get-ChildItem "${dcbBase}.*","${dcbBase}-notes.*","${dcbBase}-redlines.*"
}

function CF-Get-DbFiles-With-Sizes {
    param ( [string] $dcbPfn )
    
    # get name of full pfn without extension
    $dcbBase = CF-Get-PfnWithoutExtension $dcbPfn
    
    $files = Get-ChildItem "${dcbBase}.*","${dcbBase}-notes.*","${dcbBase}-redlines.*"
        
}

# possible status values:
# 0 = ran but failed
# 1 = in process
# 2 = ran successfully
function CF-Finish-DBRow($dbRow, $statFld) {
    if ($script:rowHasError) {
        $dbRow.$statFld = $CF_STATUS_FAILED
    }
    else {
        $dbRow.$statFld = $CF_STATUS_GOOD
    }
}

# inputs: 1) dir-to-search  2) extension, eg "txt"
function CF-Find-ListOfFilesByExt {
    param($dir, $ext)
    return Get-ChildItem -Recurse $dir | where {$_.extension -eq "$ext"}
    
}



function CF-Get-Time-From-CN-TS {
    param ([string] $ts)
    $dt = $ts.Split(" ")

    $tStr = $dt[$dt.Length-1]
    #write "tstr = $tStr`n"
    #$tArr = $tStr.Split(':')
    $tArr = $tStr -split ':',0
    
    # someday, I have to look into why I had to 
    # use a new array to hold the values as integers
    $tArr2 = @(0,0,0)
    for ($i=0; ($i -lt $tArr.Length); $i++) {
        #if ($tArr[$i] -eq "") { $tArr2[$i] = "0" }
        $tArr2[$i] = $tArr[$i] -as [int]  # convert to int  
    }

    return $tArr2
}

# later value is first arg, earlier value is 2nd, just like subtraction
# DAMN, still have to handle case of spanning midnight
function CF-Time-Diff-From-CN {
    param ([string] $tsLate, [string] $tsEarly)
    $tArr1 = CF-Get-Time-From-CN-TS($tsEarly)
    $tArr2 = CF-Get-Time-From-CN-TS($tsLate)
    
    
    # These timestamps have blanks for any value of H,M, or S = 0
    if ($tArr1[2] -gt $tArr2[2]) { $tArr2[2]+=60; $tArr2[1] -= 1 }
    if ($tArr1[1] -gt $tArr2[1]) { $tArr2[1]+=60; $tArr2[0] -= 1 }
    
    # quick hack to handle spanning midnight.  Assumes only difference of 1 day in the dates
    if ($tArr1[0] -gt $tArr2[0]) { $tArr2[0]+=24; }
   
    # calc in seconds, then convert to mins
    
    $diff = $tArr2[2] - $tArr1[2] + ( ($tArr2[1] - $tArr1[1]) * 60)
    $diff += ($tArr2[0]-$tArr1[0]) * 3600
    $diff = [math]::Round(($diff /60),1)
    $diff
}

#CF-Time-Diff-From-CN "06/18/2013  :8:59" "06/18/2013  :3:6" 

function CF-Parse-Stats-Log {
    param($pfn)
    $recs = Get-Content $pfn
    $convArr = $recs[2] -split "\|",0
    $idxArr = $recs[8] -split "\|",0
    
    $convDuration = CF-Time-Diff-From-CN $convArr[5] $convArr[4]
    
    $idxDuration = CF-Time-Diff-From-CN $idxArr[5] $idxArr[4]
    write-host ("Conv status = {0}" -f $convArr[3])
    write-host ("Idx status = {0}" -f $idxArr[3])
    write-host ("Conv time TAB idx time = {0}`t{1}" -f ($convDuration, $idxDuration))
}

function CF-Testme {
    write "got cf-testme"
    
}

# SQL

function CF-Create-SqlConnection($database = "FYI_Conversions")
{
	$conn = New-Object ('System.Data.SqlClient.SqlConnection');
    $cnstring = $global:connectionstring -replace "<DATABASE>", $database
	$conn.ConnectionString = $cnstring
    $conn.close()
	$conn.Open();
    #$cmd = New-Object System.Data.SqlClient.SqlCommand
    #$cmd.Connection = $conn;    
    return $conn;
}

function CF-Get-SQL-Cmd ($database="FYI_Conversions") {
    $conn = CF-Create-SqlConnection $database
    $cmd = New-Object System.Data.SqlClient.SqlCommand
    $cmd.Connection = $conn;
    $cmd.CommandType = [System.Data.CommandType] "Text";
    return $cmd
    #$cmd.CommandText = "insert into DCBs (orig_dcb) values ('C:\mtsadmin cdefg')"
    #[Void] $cmd.ExecuteNonQuery()
}

function CF-Show-DCB-DB-File($file="DCBs") {
    $dbFile = "$CF_DBDir\${file}.txt"
    import-CSV -delimiter "`t" $dbfile | out-gridview
}

function CF-Get-Client-Matter ($dcb) {
    $p= $dcb -split "\\"
    $clMtr = "$($p[1]).$($p[2])"
    write-host $clMtr
    return $clMtr
}

# $vers = "v8" or "v10"
function CF-Get-CN-Exe($vers) {
    if (-not ($vers)) {
        throw "Must define `$vers when calling CF-Get-CN-Exe"
    }

    $v8 = @( "C:\Program Files\Dataflight\Concordance\Concordance.exe", 
             "C:\Program Files (x86)\LexisNexis\Concordance\Concordance.exe",
             "C:\Program Files (x86)\Dataflight\Concordance\Concordance.exe"
           )

    $v10 = @("C:\Program Files\LexisNexis\Concordance 10\Concordance_10.exe",
             "C:\Program Files (x86)\LexisNexis\Concordance 10\Concordance_10.exe"
            )

    # might be 8 or 9, I guess, though usually refer to both simply as 8
    if ($vers -match "8") { $exes = $v8 }
    elseif ($vers -match "10") { $exes = $v10 }
    else { throw "Bad value for vers: $vers"  }

    foreach ($exe in $exes) {
        if (test-path $exe) {
            return $exe
        }
    }

    $msg = "Can't find CN exe for version: $vers`n"
    $msg += ($exes -join "`n")
    throw $msg
}

function CF-Get-CN-Info ($CN_Ver) {
    if (-not ($CN_Ver)) {
        throw "Must define `$CN_Ver when calling CF-Get-CN-Info"
    }

    if ($CN_Ver -match "8") { $VStr = "v8" }
    elseif ($CN_Ver -match "10") { $VStr = "v10" }
    else { throw "Bad value for CN_Ver: $CN_Ver" }

    $CN_EXE = CF-Get-CN-Exe $Vstr

    return @($Vstr, $CN_EXE)
}
    
function CF-Strip-Last-Slash ($path) {
    $len = $path.length
    if ($path.substring($len-1, 1) -eq '\') {
        return $path.substring(0, $len-1)
    }
    else {
        return $path
    }
}

function CF-Add-Arr-Item-To-Hash($hash, $key, $item) {
    if (-not ($hash.ContainsKey($key))) {
        $hash[$key] = @($item)
    }
    else {
        $hash[$key] += $item
    }
    return $hash
}

function CF-Write-Out-CM-Dbids($outFile, $CMs_h) {
    echo $null > $outFile
    foreach ($CM in $CMs_h.keys) {
        foreach ($dbid in $CMs_h[$CM]) {
            CF-Write-File $outFile "$CM|$dbid"
        }
    }
}

function CF-Get-File-Sizes($files) {
    $sizes = @()
    foreach ($dbFile in $dbFiles) {
        $size = (get-item $dbFile).length
        $sizes += @($dbFile,$size)
    }
    return $sizes
}

# stub for making a field in a table 
<#
$sqlCmdW.CommandText = @'
IF NOT EXISTS(select * from sys.columns where name = 'bytes' and object_id=object_id('folders'))    
ALTER TABLE folders ADD bytes bigint
'@
$sqlCmdW.ExecuteNonQuery() > $null
#>
