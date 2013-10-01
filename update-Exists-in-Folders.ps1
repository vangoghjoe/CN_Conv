param(
    $startRow,
    $endRow
)


. ((Split-Path $script:MyInvocation.MyCommand.Path) + "/libConversion.ps1")


function Main {
    $sqlCmd = CF-Get-SQL-Cmd $CF_DATA_ARCH_DB
    
    $sqlCmd.CommandText = "SELECT TOP 10 ID,Folder from Folders"
    $sqlCmd.ExecuteNonQuery() > $null

    $reader = $sqlCmd.ExecuteReader() #> $null
    while ($reader.Read()) {
        echo "$($reader.GetValue(0)): $($reader.GetValue(1))"
    }
    $reader.Close()
}

Main
