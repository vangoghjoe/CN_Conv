param(
    $startRow,
    $endRow
)


. ((Split-Path $script:MyInvocation.MyCommand.Path) + "/libConversion.ps1")


function Main {
    $sqlCmdW = CF-Get-SQL-Cmd $CF_DATA_ARCH_DB
    $sqlCmdW.CommandText = "update folders set bexists = @exists WHERE ID='$id'"
    
    $sqlCmdR = CF-Get-SQL-Cmd $CF_DATA_ARCH_DB

    #$sqlCmdR.CommandText = "SELECT ID,Folder from Folders"
    $sqlCmdR.CommandText = "SELECT ID,Folder from Folders WHERE bExists is null"

    $sqlCmdR.CommandText = "SELECT ID,Folder from Folders"
    $reader = $sqlCmdR.ExecuteReader() #> $null
    echo "finished read query ... whew!"

    $ct = 0
    while ($reader.Read()) {
        $ct++
        $id = $reader.GetValue(0)
        $path = $reader.GetValue(1)
        try {
            $exists = [int] $(test-path -ea stop $path)
        }
        catch {
            $exists = -1
        }
        if ($ct % 50 -eq 0) { echo "ID= $id : $ct : $exists : $path" }

        $sqlCmdW.CommandText = "update folders set bexists = $exists WHERE ID='$id'"

        #$p = $sqlCmdW.Parameters.AddWithValue("@exists",$exists) 
        #$sqlCmdW.Parameters.Add("@exists",$exists) 

        $sqlCmdW.ExecuteNonQuery() > $null
    }
    $reader.Close()
}

Main

<<<<<<< HEAD
=======

>>>>>>> 0d57f5e8aa321be053b1d8828263f8fea38c9b10
