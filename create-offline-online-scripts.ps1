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
    $FYI,  # 3 or 5
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
        $oldOnline = 1
        $newOnline = 0

    }
    else {
        $clause = " AND st_all=2" 
        $srcDrive = "X"
        $destDrive = "W"
        #$dcbName = "conv_dcb"
        $dcbName = "orig_dcb"
        $textType = "text"
        $oldOnline = 0
        $newOnline = 1
    }

    $msg = "create table $table(dbid int, dcb $textType);"
    CF-Write-File $outFile $msg 
    CF-Write-File $outFile ""

    try {
        $sCmd = CF-Get-SQL-Cmd
        $sCmd.CommandText = @"
SELECT DBID, $dcbName FROM DCBs
WHERE batchid=$batchid $clause
ORDER BY DBID
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

    if ($fyi -eq 5 -or $fyi -eq 3) {
        $msg = @"
--  Check for any that aren't in the DB 
SELECT l.dbid as 'LN recs not in DB', l.dcb, d.id from LN_temp l
LEFT OUTER JOIN [DATABASE] d
ON upper(l.dcb) = upper(replace(d.unc,'W:\Z_client','W:\client'))
WHERE d.id is null;

-- Check for dups
select UNC,COUNT(UNC) as 'dups' from [DATABASE] 
where upper(replace(unc,'W:\Z_client','W:\client'))
(select dcb from LN_temp)
group by UNC
having COUNT(UNC) > 1;


--  Check for any that have an unexpected ONLINE value
SELECT l.dbid as 'unexpected online=$newonline', l.dcb, d.id from LN_temp l
LEFT OUTER JOIN [DATABASE] d
ON upper(l.dcb) = upper(replace(d.unc,'W:\Z_client','W:\client'))
WHERE d.online=$newOnline;

-- COUNT of all new online val BEFORE
SELECT COUNT(*) as 'num online=$newOnline BEFORE' FROM [database]
WHERE online=$newOnline;

-- Flip the Online value
--UPDATE [database] 
--SET online=$newOnline 
--WHERE upper(replace(d.unc,'W:\Z_client','W:\client')) IN 
--    (SELECT upper(dcb) FROM LN_temp);

-- COUNT of all new online val AFTER
--SELECT COUNT(*) as 'num online=$newOnline AFTER' FROM [database]
--WHERE online=$newOnline;


-- Check the count of the ones we wanted to change
--SELECT * from LN_temp l
--LEFT OUTER JOIN [DATABASE] d
--ON upper(l.dcb) = upper(replace(d.unc,'W:\Z_client','W:\client'))
--WHERE d.online=$newOnline;

-- Remove our "temp" table
--DROP TABLE $table;
"@
        }
        CF-Write-File $outFile $msg
    }
    finally {
        $reader.Close()
        $sCmd.Connection.Close()
    }
}

Main


