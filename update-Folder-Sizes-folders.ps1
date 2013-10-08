param(
    [int] $offset,
    [int] $fetchNum
)


. ((Split-Path $script:MyInvocation.MyCommand.Path) + "/libConversion.ps1")


function Main {
    $sqlCmdW = CF-Get-SQL-Cmd $CF_DATA_ARCH_DB

    # ADD COLUMN DCBs.natives_foldersbytes and .images_folders_bytes
    $sqlCmdW.CommandText = @'
IF NOT EXISTS(select * from sys.columns where name = 'bytes' and object_id=object_id('folders'))    
ALTER TABLE folders ADD bytes bigint
'@
    $sqlCmdW.ExecuteNonQuery() > $null
    $sqlCmdW.CommandText = @'
IF NOT EXISTS(select * from sys.columns where name = 'files' and object_id=object_id('folders'))    
ALTER TABLE folders ADD files bigint
'@
    $sqlCmdW.ExecuteNonQuery() > $null

    # Set up query to get dcbs
    # For now, get those ready for archive, but not TBA
    $sqlCmdR_DCBs = CF-Get-SQL-Cmd $CF_DATA_ARCH_DB
    $cmd = @"
SELECT dbid, orig_dcb FROM DCBs WHERE bReadyForArchive = 0 
"@
	# SELECT dbid, orig_dcb FROM DCBs WHERE bReadyForArchive = 1 and bTBA = 1 
	if ($offset) {
		$cmd += @" 
ORDER BY DBID
OFFSET $offset ROWS
FETCH NEXT $fetchNum ROWS ONLY
"@
	}
	$sqlCmdR_DCBs.CommandText = $cmd
    
    # Loop over DCBs
    $DCBsreader = $sqlCmdR_DCBs.ExecuteReader() #> $null
    $ct = 0
    while ($DCBsreader.Read()) {
        $dbid = $DCBsreader.GetValue(0)
        $ct++
        if ($ct % 3 -eq 0) { echo "ID= $dbid : $ct : $orig_dcb" }
        echo "ID= $dbid : $ct : $orig_dcb"

        # Set up query to get folders for each 
        # For now, get those ready for archive, but not TBA
        # and only those that exist
        $sqlCmdR_Folders = CF-Get-SQL-Cmd $CF_DATA_ARCH_DB
        $sqlCmdR_Folders.CommandText = @"
SELECT ID, Folder FROM Folders WHERE DBID=$dbid AND bExists=1
"@
        echo $sqlCmdR_Folders.CommandText
        $foldersReader = $sqlCmdR_Folders.ExecuteReader()
        while ($foldersReader.Read()) {
            $id = $foldersReader.GetValue(0)
            $folder = $foldersReader.GetValue(1)

            # if the path to the folder doesn't exist, set the size to -1 
            # and go back to top of loop
            if (-not (test-path $folder)) {
                ($bytes, $files) = (-1, -1)
            }
            else {
                # Get the bytes and file count
                ($bytes, $files) = CF-Get-Num-Files-And-Size-Of-Folder $folder
            }
            echo "[$dbid] ($bytes)($files) $folder"
            $sqlCmdW.CommandText = @"
UPDATE folders SET bytes=$bytes, files=$files WHERE id=$id
"@
            $sqlCmdW.ExecuteNonQuery() > $null
        }
    }
    $DCBsreader.Close()
}

Main

