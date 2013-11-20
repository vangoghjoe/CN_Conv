param(
    $startRow,
    $endRow
)

# hit me


. ((Split-Path $script:MyInvocation.MyCommand.Path) + "/libConversion.ps1")


# Will get called twice, once for orig, again for conv
# Each will simply add the filenames it finds to the total
# files_h hash, without worrying about which added what.
# Then in "Add-Files-To-DB", each filename will be tested against
# both orig and conv directories
function Get-DbFiles-Arch ($dcbPfn) {
    # get name of full pfn without extension
    $dcbBase = CF-Get-PfnWithoutExtension $dcbPfn
    
    # Main CN files    
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

    # put in list

    # Add to files_h
    foreach ($file in $files) {
        $name = [system.io.path]::GetFilename($file.fullname)
        $script:files_h[$name] = ''
    }

}

function Add-File-To-DB ($dbid, $orig_dcb, $conv_dcb,  $sqlCmd) {
    $origDir = [system.io.path]::GetDirectoryName($orig_dcb)
    $convDir = [system.io.path]::GetDirectoryName($conv_dcb)

    if (-not (test-path $origDir)) {
        $sqlCmdW.CommandText = @"
UPDATE DCBs SET bOrigFolderMissing = 1 WHERE dbid = $dbid
"@
        $sqlCmdW.ExecuteNonQuery()
    }
    if (-not (test-path $convDir)) {
        $sqlCmdW.CommandText = @"
UPDATE DCBs SET bConvFolderMissing = 1 WHERE dbid = $dbid
"@
        $sqlCmdW.ExecuteNonQuery()
    }

    foreach ($file in $script:files_h.Keys) {
        $origFile = "$origDir\$file"
        if (test-path $origFile) {
            $origExists = 1
            $origSize = $(get-item $origFile).length
        }
        else {
            $origExists = 0
            $origSize = "NULL"
        }

        $convFile = "$convDir\$file"
        if (test-path $convFile) {
            $convExists = 1
            $convSize = $(get-item $convFile).length
        }
        else {
            $convExists = 0
            $convSize = "NULL"
        }

        $sqlCmd.CommandText = @"
insert into DCB_Files (dbid, name, bOrig_exists, orig_bytes, bConv_exists, conv_bytes, orig_pfn, conv_pfn)
 values($dbid, '$file', $origExists, $origSize, $convExists, $convSize, '$origFile', '$convFile')
"@
        $sqlCmd.ExecuteNonQuery() > $null
        #write-host $sqlcmd.commandtext
    }

}

function Main {
    # will be used for db updates
    $sqlCmdW = CF-Get-SQL-Cmd $CF_DATA_ARCH_DB

    # Clear Orig/Conv Folder Missing 
    write-host "Clearing orig/conv FolderMissing"
    $sqlCmdW.CommandText = @"
UPDATE DCBs SET bOrigFolderMissing = 0, bConvFolderMissing = 0 
"@
    $sqlCmdW.ExecuteNonQuery()
    write-host "Done"

    # CREATE TABLE DCB_Files
    <#
    $sqlCmdW.CommandText = @'
IF NOT EXISTS(select * from sys.columns where name = 'bytes' and object_id=object_id('folders'))    
ALTER TABLE folders ADD bytes bigint
'@
    $sqlCmdW.ExecuteNonQuery() > $null
    #>

    # Query to get orig and conv dcbs from DCBs
    $sqlCmdR_DCBs = CF-Get-SQL-Cmd $CF_DATA_ARCH_DB
    $sqlCmdR_DCBs.CommandText = @'
SELECT dbid, orig_dcb, conv_dcb FROM DCBs 
'@
    
    # Loop over DCBs
    $DCBsreader = $sqlCmdR_DCBs.ExecuteReader() #> $null
    $ct = 0
    while ($DCBsreader.Read()) {
        $dbid = $DCBsreader.GetValue(0)
        $ct++
        if ($ct % 10 -eq 0) { echo "ID= $dbid : $ct : $orig_dcb" }
        echo "ID= $dbid : $ct : $orig_dcb"

        $dbid = $DCBsreader.getvalue(0) 
        $origDcb = $DCBsreader.getvalue(1) 
        $convDcb = $DCBsreader.getvalue(2) 
	   $x = $convDcb -replace "Test\\\\Bkup", "Test\Bkup"
       $convDcb = $x
       write-host  $convDcb
        
        # still having problems passing a hash around
        $script:files_h = @{}
        
        Get-DbFiles-Arch $origDcb
        Get-DbFiles-Arch $convDcb

        Add-File-To-DB $dbid $origDcb $convDcb $sqlCmdW
    }
    $DCBsreader.Close()
}

Main


