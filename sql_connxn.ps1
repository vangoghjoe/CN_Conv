$global:connectionstring = "Server=LNGHBEL-5009970\SQLEXPRESS; Database=FYI_Conversions; User Id=conv_user;"
$global:connectionstring += ("Password=fr33d0m!;" )


function Create-SqlConnection()
{
	$conn = New-Object ('System.Data.SqlClient.SqlConnection');
	$conn.ConnectionString = $global:connectionstring;
	$conn.Open();
    $cmd = New-Object System.Data.SqlClient.SqlCommand
    $cmd.Connection = $conn;    
    return $conn;
}

$conn = Create-SqlConnection
$cmd = New-Object System.Data.SqlClient.SqlCommand
$cmd.Connection = $conn;
$cmd.CommandType = [System.Data.CommandType] "Text";
$cmd.CommandText = "insert into DCBs (conv_pfn) values ('C:\abcdefg')"
[Void] $cmd.ExecuteNonQuery()
