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

param(
    $BatchID,
    $DriverFile,
    $startRow,
    $endRow
)


. ((Split-Path $script:MyInvocation.MyCommand.Path) + "/libConversion.ps1")


function Main {
    #CF-Log-To-Master-Log $runEnv.bstr "" "START" "Start row=$startRow  End row=$endRow"
    $startDate = $(get-date -format $CF_DateFormat)

    $dcbRows = CF-Read-DB-File "DCBs" "BatchID" $BatchID
    echo $null > $CF_CM_TBA_Dbids

    # DCB Rows Loop
    # Build list of TBA's, making sure to add all of them to the new rows   
    for ($i = 0 ; $i -lt $dcbRows.length ; $i++) {
        $row = $dcbRows[$i]
        
        if ($row.batchid -ne "3") {   
            continue
        }

        $clMtr = CF-Get-Client-Matter $row.orig_dcb
        CF-Write-File $CF_CM_TBA_Dbids "${clMtr}|$($row.dbid)"

    }

}     

Main
