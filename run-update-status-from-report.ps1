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
    [switch]$ForCompareDict,
    [switch]$ForAllReports,
    [switch]$ForWholeShebang
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
    elseif ($ForAllReports) {
        $ColName = "st_qc_all_reports_manual"
    }
    elseif ($ForWholeShebang) {
        $ColName = "st_all_manual"
    }

    if ($ColName -eq $null) { echo "use -For* to enter report type" ; return } 

    $RmName = "st_remove"

    $rows = get-content $reportFile

    foreach ($row in $rows) { 
        $cols = $row -split $reportFileDelim
        $cleared = $cols[0]
        $dbid = $cols[2]

        # Header row
        if ($dbid -eq 'dbid') { continue }

        if (!($dbid -match "^\d+$")) {
            echo "ERROR: dbid blank or not numeric: line $linect"
            continue
        }

        if ($cleared -match "c") { 
            $ColValue = 2
            $RmValue = "null"
        }
        elseif ($cleared -match "r") { 
            $ColValue = "null"
            $RmValue = "2"
        }
        elseif ($cleared -eq "") { 
            #hmmm, if blank, should it clear everything or just leave it alone?
            # --> leave it alone
            continue
        }
        else {
            echo "Error: invalid value for 'cleared' col: $cleared"
            continue
        }

        $sCmd.CommandText = @"
-- _manual_results column
UPDATE DCBs SET $ColName=$ColValue WHERE batchid=$BatchID and dbid=$dbid;
-- St_remove column
UPDATE DCBs SET $RmName=$RmValue WHERE batchid=$BatchID and dbid=$dbid;
"@
        write-verbose $scmd.CommandText
        $sCmd.ExecuteNonQuery() > $null
        #mv $reportFile "$reportFile.LOADED.txt"
    }

}

Main
