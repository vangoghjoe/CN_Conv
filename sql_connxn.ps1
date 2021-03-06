
# For remote for conv_user (using SQL Server Auth)
#   got this to work where con_user is
#     set to SQL Server Auth
#     mapped to a user in FYI_Conversions DB using Logins->User Mappings (not from the DB itself)
#     added 
#$global:connectionstring = "Server=HL105SPRSQL03\FYI; Database=FYI_Conversions; User Id=conv_user;"
#$global:connectionstring += ("Password=fr33d0m!;" )

# for remote for mtsadmin - uses Windows Auth
# TRY "Initial catalog" if "Database" doesn't work

# TO HL105SQL03
$global:connectionstring = "Server=HL105SPRSQL03\FYI; Database=FYI_Conversions; Integrated Security = True"

# TO SQL EXPRESS ON CON01
$global:connectionstring = "Server=HL105SPRCON01\SQLEXPRESS; Database=FYI_Conversions; Integrated Security = True"
write-host $connectionstring

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
$cmd.CommandText = "insert into DCBs (orig_dcb) values ('C:\mtsadmin cdefg')"
[Void] $cmd.ExecuteNonQuery()
