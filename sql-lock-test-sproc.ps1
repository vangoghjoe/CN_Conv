param(
    $instanceNum
)
set-strictmode -version 2
#$instanceNum = 5

. ((Split-Path $script:MyInvocation.MyCommand.Path) + "/libConversion.ps1")


function Main {
    $fileOut = "$instanceNum.log"
    echo $null > $fileOut
    
    $cmd = CF-Get-SQL-Cmd "FYI_Conversions"

    # Getting a return value from a stored procedure
    $cmd.CommandType = [System.Data.CommandType] 'StoredProcedure'
    $cmd.CommandText = 'uspGetNextID'

    # set input param
    $cmd.Parameters.AddWithValue("@caller",$instanceNum) > $null 
    # get output param
    $param = new-object System.Data.SqlClient.SqlParameter;
    $param.ParameterName = '@ID'
    $param.Direction = [System.Data.ParameterDirection] 'Output'
    $param.DbType = [System.Data.DbType]'Int64'
    $cmd.Parameters.Add($param) > $null
    $caller  = 70
    while (1) {
        $cmd.Parameters["@ID"].Value = [system.dbnull]::Value
        $res = $cmd.ExecuteNonQuery()
        $id = $cmd.Parameters["@ID"].Value
        echo "id = $id"
        if ($id -eq [system.dbnull]::Value) { echo "null"; break }
        $id |  out-file -append -Encoding ascii $fileOut
        $caller++
        #$cmd.Parameters["@caller"].Value = $caller > $null 
        #if ($caller -gt 75) { echo "caller = $caller" ; break }
        sleep 1
    }
}

Main

