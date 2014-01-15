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
[CmdLetBinding()]
param(
    [parameter(mandatory=$true)]
    $BatchID,
    [switch]$DoBackups,
    $BackupDirRootLocalV8,
    $BackupDirRootConv,
    [switch]$DoGetNumDictLines,
    [switch]$UseTestDirs,
    [switch]$UseRealDirs,
    $fileStub = "run-all",
    $startRow,
    $endRow,
    [switch] $ignoreStatus,
    $DBId,
    $DriverFile
)

set-strictmode -version latest

. ((Split-Path $script:MyInvocation.MyCommand.Path) + "/libConversion.ps1")

# Ignore non-MultiFileSets for now
function Main {
    $runEnv = CF-Init-RunEnv $BatchID 
    $startDate = $(get-date -format $CF_DateFormat)
    if ($UseTestDirs) {
        $BackupDirRootLocalV8 = "W:\_LN_Test\Pre-conversion\batch${BatchID}\localv8"
        $BackupDirRootConv = "W:\_LN_Test\Pre-conversion\batch${BatchID}\Conv"
    }
    elseif ($UseRealDirs) {
        $BackupDirRootLocalV8 = "W:\_LN_Test\Pre-conversion\batch${BatchID}\localv8"
        $BackupDirRootConv = "W:"
    }

    CF-Log-To-Master-Log $runEnv.bstr "" "STATUS" "Start Start row=$startRow  End row=$endRow"

    if ($DoBackups) {
        if (($BackupDirRootLocalV8 -eq $null) -or ($BackupDirRootConv -eq $null)) {
            echo "Must specify backupdirs if doing backups"
            return
        }
    }
   
    $cmds= @()
    #"run-update-conv-statuses-SQL.ps1 -pgmall -FileStub $fileStub",
    if ($DoBackups) {
        $cmds += @(
        "backup-for-conversion.ps1  -backupDirRoot $BackupDirRootLocalV8 -FileSetLocalv8 -WriteToDbFile",
        "backup-for-conversion.ps1 -backupDirRoot $BackupDirRootConv -FileSetConv -WriteToDbFile",
        "run-update-conv-statuses-SQL.ps1 -pgmall -FileStub $fileStub"
        )
    }
    $cmds += @(
    "run-qc-tags.ps1 -CN_Ver 8 -useMultiFileSets ",
    "run-update-conv-statuses-SQL.ps1 -pgmall -FileStub $fileStub",
    "run-qc-list-dict.ps1 -CN_Ver 8 -useMultiFileSets ",
    "run-update-conv-statuses-SQL.ps1 -pgmall -FileStub $fileStub",
    "run-qc-dict-pick-qc-words.ps1  ",
    "run-update-conv-statuses-SQL.ps1 -pgmall -FileStub $fileStub",
    "run-qc-query-dict.ps1 -CN_Ver 8 -useMultiFileSets ",
    "run-update-conv-statuses-SQL.ps1 -pgmall -FileStub $fileStub",
    "run-convert-one-dcb.ps1  ",
    "run-update-conv-statuses-SQL.ps1 -pgmall -FileStub $fileStub",
    "run-qc-tags.ps1 -CN_Ver 10 ",
    "run-update-conv-statuses-SQL.ps1 -pgmall -FileStub $fileStub",
    "run-qc-compare-tags.ps1",
    "run-update-conv-statuses-SQL.ps1 -pgmall -FileStub $fileStub",
    "run-qc-list-dict.ps1 -CN_Ver 10  ",
    "run-update-conv-statuses-SQL.ps1 -pgmall -FileStub $fileStub",
    "run-qc-query-dict.ps1 -CN_Ver 10 ",
    "run-update-conv-statuses-SQL.ps1 -pgmall -FileStub $fileStub",
    "run-qc-compare-dict.ps1 ",
    "parse-conversion-report.ps1",
    "run-update-conv-statuses-SQL.ps1 -pgmall -FileStub $fileStub"
    )

    foreach ($cmd in $cmds) {
        $cmd += " -BatchID $BatchID"
        if ($startRow -ne $null) {
            $cmd += " -startRow $startRow"
        }
        
        if ($endRow -ne $null) {
            $cmd += " -endRow $endRow"
        }
        
        if ($DBid -ne $null) {
            $cmd += " -DBId $dbid"
        }
        if ($DriverFile -ne $null) {
            $cmd += " -DriverFile $DriverFile"
        }

        if ($cmd -match 'compare-dict' -and $DontCountDictRecs) {
            $cmd += " -DontCountRecs"
        }
        echo $cmd
        invoke-expression $cmd
        echo ""
    }

    CF-Log-To-Master-Log $runEnv.bstr "" "STATUS" "STOP  Start row=$startRow  End row=$endRow"
    $endDate = $(get-date -format $CF_DateFormat)
    write-host "*** Done: batch = $BatchID Start row=$startRow  End row=$endRow"
    write-host "Start: $startDate"
    write-host "End:   $endDate"
}     

Main

