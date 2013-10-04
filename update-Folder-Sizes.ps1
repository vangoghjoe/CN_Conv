param(
    $startRow,
    $endRow
)


. ((Split-Path $script:MyInvocation.MyCommand.Path) + "/libConversion.ps1")


function Main {
    $sqlCmdW = CF-Get-SQL-Cmd $CF_DATA_ARCH_DB

    # ADD COLUMN DCBs.natives_foldersbytes and .images_folders_bytes
    $sqlCmdW.CommandText = @'
IF NOT EXISTS(select * from sys.columns where name = 'natives_folders_bytes' and object_id=object_id('DCBs'))    
ALTER TABLE DCBs ADD natives_folders_bytes bigint
'@
    $sqlCmdW.ExecuteNonQuery() > $null
    $sqlCmdW.CommandText = @'
IF NOT EXISTS(select * from sys.columns where name = 'images_folders_bytes' and object_id=object_id('DCBs'))    
ALTER TABLE DCBs ADD images_folders_bytes bigint
'@
    $sqlCmdW.ExecuteNonQuery() > $null

    # Set up query to get dcbs
    # For now, get those ready for archive, but not TBA
    $sqlCmdR_DCBs = CF-Get-SQL-Cmd $CF_DATA_ARCH_DB
    $sqlCmdR_DCBs.CommandText = @'
SELECT dbid, orig_dcb FROM DCBs WHERE bReadyForArchive = 1 
'@

    # Set up query to get folders for each 
    # For now, get those ready for archive, but not TBA
    $sqlCmdR_Folders = CF-Get-SQL-Cmd $CF_DATA_ARCH_DB
    $sqlCmdR_Folders.CommandText = @'
SELECT ID, Folder FROM Folders WHERE DBID=
'@
    
    # Loop over DCBs
    $DCBsreader = $sqlCmdR_DCBs.ExecuteReader() #> $null
    $ct = 0
    while ($DCBsreader.Read()) {
        $dbid = $DCBsreader.GetValue(0)
        $orig_dcb = $DCBsreader.GetValue(1)
        $ct++
        if ($ct % 3 -eq 0) { echo "ID= $dbid : $ct : $orig_dcb" }
        echo "ID= $dbid : $ct : $orig_dcb"

        # if the path to the orig_dcb doesn't exist, set the size to -1 
        # and go back to top of loop
        if (-not (test-path $orig_dcb)) {
            ($db_bytes, $db_files) = (-1, -1)
        }
        else {
            # Update the db_bytes
            $dir = [system.io.path]::GetDirectoryName($orig_dcb)
            ($db_bytes, $db_files) = CF-Get-Num-Files-And-Size-Of-Folder $dir
        }
        $sqlCmdW.CommandText = @"
UPDATE DCBs SET db_bytes=$db_bytes, db_files=$db_files WHERE dbid=$dbid
"@
        $sqlCmdW.ExecuteNonQuery() > $null
    }
    $DCBsreader.Close()
}

Main


