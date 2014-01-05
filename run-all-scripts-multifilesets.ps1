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
    [parameter(mandatory=$true)]
    $BackupDirRootLocalV8,
    [parameter(mandatory=$true)]
    $BackupDirRootConv,
    [parameter(mandatory=$true)]
    $fileStub,
    $startRow,
    $endRow,
    [switch] $ignoreStatus,
    $DBId
)

set-strictmode -version latest

. ((Split-Path $script:MyInvocation.MyCommand.Path) + "/libConversion.ps1")

# Ignore non-MultiFileSets for now
function Main {
    $runEnv = CF-Init-RunEnv $BatchID 
    $startDate = $(get-date -format $CF_DateFormat)
    if ($startRow -eq $null) { $startRow = 1 }
    if ($endRow -eq $null) { $endRow = 9999 }

    CF-Log-To-Master-Log $runEnv.bstr "" "STATUS" "Start Start row=$startRow  End row=$endRow"
   
    $cmds= @(
    #"run-update-conv-statuses-SQL.ps1 -pgmall -FileStub $fileStub",
    #"backup-for-conversion.ps1  -backupDirRoot $BackupDirRootLocalV8 -FileSetLocalv8",
    #"backup-for-conversion.ps1 -backupDirRoot $BackupDirRootConv -FileSetConv",
    #"run-update-conv-statuses-SQL.ps1 -pgmall -FileStub $fileStub",
    #"run-qc-tags.ps1 -CN_Ver 8 -useMultiFileSets ",
    #"run-update-conv-statuses-SQL.ps1 -pgmall -FileStub $fileStub",
    #"run-qc-list-dict.ps1 -CN_Ver 8 -useMultiFileSets ",
    #"run-update-conv-statuses-SQL.ps1 -pgmall -FileStub $fileStub",
    #"run-qc-dict-pick-qc-words.ps1  ",
    #"run-update-conv-statuses-SQL.ps1 -pgmall -FileStub $fileStub",
    #"run-qc-query-dict.ps1 -CN_Ver 8 -useMultiFileSets ",
    #"run-update-conv-statuses-SQL.ps1 -pgmall -FileStub $fileStub",
    #"run-convert-one-dcb.ps1  ",
    #"run-update-conv-statuses-SQL.ps1 -pgmall -FileStub $fileStub",
    #"run-qc-tags.ps1 -CN_Ver 10 ",
    #"run-update-conv-statuses-SQL.ps1 -pgmall -FileStub $fileStub",
    #"run-qc-compare-tags.ps1",
    #"run-update-conv-statuses-SQL.ps1 -pgmall -FileStub $fileStub",
    #"run-qc-list-dict.ps1 -CN_Ver 10  ",
    #"run-update-conv-statuses-SQL.ps1 -pgmall -FileStub $fileStub",
    #"run-qc-query-dict.ps1 -CN_Ver 10 ",
    #"run-update-conv-statuses-SQL.ps1 -pgmall -FileStub $fileStub",
    "run-qc-compare-dict.ps1 ",
    "run-update-conv-statuses-SQL.ps1 -pgmall -FileStub $fileStub"
    )

    foreach ($cmd in $cmds) {
        $cmd += " -BatchID $BatchID -startRow $startRow -endRow $endRow"
        if ($DBid -ne $null) {
            $cmd += " -DBId $dbid"
        }
        echo $cmd
        invoke-expression $cmd
    }

    CF-Log-To-Master-Log $runEnv.bstr "" "STATUS" "STOP  Start row=$startRow  End row=$endRow"
    $endDate = $(get-date -format $CF_DateFormat)
    write-host "*** Done: batch = $BatchID Start row=$startRow  End row=$endRow"
    write-host "Start: $startDate"
    write-host "End:   $endDate"
}     

Main
