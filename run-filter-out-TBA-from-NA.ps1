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
    $tba_h = @{}
    $new_rows = @()

    # DCB Rows Loop
    # Build list of TBA's, making sure to add all of them to the new rows   
    for ($i = 0 ; $i -lt $dcbRows.length ; $i++) {
        $row = $dcbRows[$i]
        
        if ($row.batchid -ne "3") {   
            continue
        }

        $dcb = $row.orig_dcb
        $dcb = $dcb.toUpper()
        $tba_h[$dcb] = ""

        $new_rows += $row

    }

    # Filter out from NA's, only adding row to new row if the orig_dcb isn't in the TBA list
    for ($i = 0 ; $i -lt $dcbRows.length ; $i++) {
        $row = $dcbRows[$i]
        
        if ($row.batchid -ne "4") {   
            continue
        }

        $dcb = $row.orig_dcb
        $dcb = $dcb.toUpper()
        if (-not ($tba_h.ContainsKey($dcb))) {
            $new_rows += $row
        }
    }

    CF-Write-DB-File "DCBs" $new_rows

}     

Main
