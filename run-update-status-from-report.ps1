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
    [parameter(mandatory=$true)]
    $BatchID,
    [parameter(mandatory=$true)]
    $ReportFile,
    [switch]$ForConvReport,
    [switch]$ForCompareTags,
    [switch]$ForCompareDict
)

set-strictmode -version latest

. ((Split-Path $script:MyInvocation.MyCommand.Path) + "/libConversion.ps1")


function Main {
    # Inits
    $sCmd = CF-Get-SQL-Cmd
    $reportFileDelim = "`t"
    if ($ForConvReport) { 
        $ColName = "st_qc_conv_report_results_manual"
    }
    elseif ($ForCompareDict) {
        $ColName = "st_qc_compare_dict_results_manual"
    }
    elseif ($ForCompareTags) {
        $ColName = "st_qc_compare_tags_results_manual"
    }
    if ($ColName -eq $null) { echo "use -For* to enter report type" ; return } 

    $rows = get-content $reportFile

    foreach ($row in $rows) { 
        $cols = $row -split $reportFileDelim
        $cleared = $cols[0]
        $dbid = $cols[2]
        if ($dbid -eq 'dbid') { continue }
        if ($cleared -ne "") { $ColValue = 2 }
        else {$ColValue = "null" }
        $sCmd.CommandText = @"
UPDATE DCBs SET $ColName=$ColValue WHERE batchid=$BatchID and dbid=$dbid
"@
        write-verbose $scmd.CommandText
        $sCmd.ExecuteNonQuery() > $null
    }
}

Main
