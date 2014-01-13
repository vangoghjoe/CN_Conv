<#
SYNOPSIS 

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
[CmdLetBinding()]
param(
    [Parameter(mandatory=$true)]
    $BatchID,
    [Parameter(mandatory=$true)]
    $FYI,
    [Parameter(mandatory=$true)]
    $outFile
)

set-strictmode -version latest

. ((Split-Path $script:MyInvocation.MyCommand.Path) + "/libConversion.ps1")

function Main {
    # Inits
    $table = "LN_temp"
    echo $null > $outFile

    if ($FYI -eq 3) { 
        $clause = ""
        $srcDrive = "X"
        $destDrive = "X"
        $dcbName = "orig_dcb"
        $textType = "nvarchar(max)"
    }
    else {
        $clause = " AND st_all=1" 
        $srcDrive = "X"
        $destDrive = "W"
        #$dcbName = "conv_dcb"
        $dcbName = "orig_dcb"
        $textType = "text"
    }

    $msg = "create table $table(dbid int, dcb $textType);"
    CF-Write-File $outFile $msg 
    CF-Write-File $outFile ""

    try {
        $sCmd = CF-Get-SQL-Cmd
        $sCmd.CommandText = @"
SELECT DBID, $dcbName from DCBs
where batchid=$batchid $clause
"@
        write-verbose $scmd.CommandText
        $reader = $sCmd.ExecuteReader()
        while ($reader.Read()) {
            $dbid = $reader.Item('dbid')
            $dcb = $reader.Item($dcbName)
            write-verbose "dcbval = $dcb"
            $dcb = $dcb -replace "'","''"
            write-verbose "dcbval = $dcb"
            $srcPat = "${srcDrive}:"
            $destPat = "${destDrive}:\client_matters\FYI"
            write-verbose "srcpat = $srcpat"
            write-verbose "destPat = $destPat"
            $dcb = $dcb -replace $srcPat,$destPat
            write-verbose "dcbval = $dcb"
            $msg = "INSERT INTO $table VALUES($dbid,'$dcb');"
            CF-Write-File $outFile $msg
        }

    $msg = @"
SELECT l.dbid, l.dcb, d.id from LN_temp l
LEFT OUTER JOIN [DATABASE] d
ON l.dcb = d.unc
WHERE d.id is null;
"@

UPDATE [database] set online=1 where upper(unc) in (select upper(dcb) from LN_temp);

SELECT count(*) from LN_temp l
LEFT OUTER JOIN [DATABASE] d
ON upper(l.dcb) = upper(d.unc)
WHERE d.online=1;


    CF-Write-File $outFile $msg 

    $msg = "`ndrop table $table;"
    CF-Write-File $outFile $msg 
    }
    finally {
        $reader.Close()
        $sCmd.Connection.Close()
    }
}

Main


