param(
    $startRow,
    $endRow
)


. ((Split-Path $script:MyInvocation.MyCommand.Path) + "/libConversion.ps1")


function Main {
    $sqlCmdW = CF-Get-SQL-Cmd $CF_DATA_ARCH_DB
    $sqlCmdW.CommandText = "update folders set bexists = @exists WHERE ID='$id'"
    
    $sqlCmdR = CF-Get-SQL-Cmd $CF_DATA_ARCH_DB
    $sqlCmdR.CommandText = "SELECT TOP 1 ID,Folder from Folders"
    $reader = $sqlCmdR.ExecuteReader() #> $null
    while ($reader.Read()) {
        $id = $reader.GetValue(0)
        $path = $reader.GetValue(1)
        $exists = [int] $(test-path $path)
        echo "exists = $exists for $path"

        $sqlCmdW.CommandText = "update folders set bexists = $exists WHERE ID='$id'"

        #$p = $sqlCmdW.Parameters.AddWithValue("@exists",$exists) 
        #$sqlCmdW.Parameters.Add("@exists",$exists) 

        $sqlCmdW.ExecuteNonQuery()
    }
    $reader.Close()
}

Main
