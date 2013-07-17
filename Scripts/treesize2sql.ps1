Param(
    [Parameter(Mandatory=$true)]
    [string]$configfile
)
Set-PSDebug -Strict

<#
    .SYNOPSIS 
      Runs treesize and uploads data to SQL server from given configuration file
    .EXAMPLE
     treesizetosql.ps1 -configfile filename"
     This command requires the config xml file to contain the following items:
        <config>
            <shares depth="1">
                <share>\\some\path</share>
                ...
            </shares>
            <treesize>
                <exe>C:\Program Files (x86)\JAM Software\TreeSize Professional\TreeSize.exe</exe>
                <arguments>/SIZEUNIT 3 /SAVE &quot;$csvfilename&quot; &quot;$share&quot;</arguments>
            <treesize>
            <sql>
                <servername>...</servername>
                <username>...</username>
                <password>...</password>
            </sql>
        </config>
#>


<#
Formated output
#>
function Write-Output($message, $iserror=$false)
{
    $message = ("{0} {1}" -f (Get-Date -Format s), $message);
    
    if ($iserror -eq $true)
    {
        $Host.UI.WriteErrorLine($message);
        if ($global:config.config.logfile -ne $null)
        {
            $message | Out-File $global:config.config.logfile -Append
        }
    }
    else
    {
        Write-Host $message;
        if ($global:config.config.logfile -ne $null)
        {
            $message | Out-File $global:config.config.logfile -Append
        }

    }
}

<#
Loads configuration file into global variables
#>
function Load-Config($configfile)
{
    Write-Output "Loading configfile $configfile"
    
    if ((Test-Path -LiteralPath $configfile) -eq $false)
    {
        Write-Output "Configuration file $configfile was not found" -iserror $true;
        exit -1;
    }

    $global:config = [xml] (Get-Content -Path $configfile);
	
	# Connection string
	$global:connectionstring = ("Server={0};Database={1};User Id={2};Password={3};" -f $global:config.config.sql.servername, `
																					   $global:config.config.sql.database, `
																					   $global:config.config.sql.username, `
																					   $global:config.config.sql.password);

	# Test sql connection
	try
	{
		$conn = Create-SqlConnection;
		$conn.Close();
	}
	catch
	{
		Write-Output $_.Exception.Message -iserror $true
		exit -2;
	}
	
	# Default depth
	$global:defaultdepth = $global:config.config.shares.depth;
	if ($global:defaultdepth -eq $null)
	{
		$global:defaultdepth = 1;
	}
}

<#
Creates a sql connection object from the $global:connectionstring
#>
function Create-SqlConnection()
{
	$conn = new-object ('System.Data.SqlClient.SqlConnection');
	$conn.ConnectionString = $global:connectionstring;
	$conn.Open();
    return $conn;
}

<#
Runs treesize for given share, returns filename of csv file
#>
function Run-TreeSize($exe,$arguments,$path, $depth)
{
	$csvfile = Join-Path -Path $global:config.config.csvpath -ChildPath (Get-SafeFilename $path)
	$csvfile += ".csv";
	Write-Output "Running tree size for $path output to $csvfile";
	
	$arguments = $arguments -replace "\[csvfile\]", $csvfile;
	$arguments = $arguments -replace "\[path\]", $path;
	
    if ($depth -gt 1)
    {
        $arguments = "/EXPAND $depth " + $arguments
    }
    
	try
	{
        $result = (Start-Process -FilePath $exe -ArgumentList $arguments -Wait -PassThru).ExitCode;
	}
	catch
	{
        throw $_.Exception;
	}
	Write-Output "Exit code $result";
	
	return $csvfile;
}

<#
Returns invalid filename chars for given string
#>
function Get-SafeFilename($name)
{
	$invalidchars = ([io.path]::GetInvalidFileNamechars());
	
	for($i = 0; $i -lt $invalidchars.Length; $i++)
	{
		$invalidchar =  [regex]::escape($invalidchars[$i]);
		$name = ($name -replace $invalidchar, "_");
	}
	
	return $name;
}


<#
Saves treesize csv to SQL
#>
function Save-ResultsToSQL($csvfile, $path)
{
	Write-Output "Saving results $csvfile to SQL";

	# Delete prior results from staging table for this path
	$conn = Create-SqlConnection;
    $cmd = New-Object System.Data.SqlClient.SqlCommand
    $cmd.Connection = $conn;
	$cmd.CommandType = [System.Data.CommandType] "Text";
	$cmd.CommandText = ("DELETE FROM {0} WHERE fullpath LIKE @fullpath" -f $global:config.config.sql.stagingtable);
	
	[void] $cmd.Parameters.Add("fullpath", [System.Data.SqlDbType] "NVarChar", 450);
	$cmd.Parameters["fullpath"].Value = "$path%";

	[Void] $cmd.ExecuteNonQuery();
	
	# Add each row to staging
	$sizedata = (Get-Content $csvfile | Select -Skip 6) -replace "\s+\,", ",";

    $cmd.Parameters.Clear();
	$cmd.CommandText = ("INSERT INTO {0} ([fullpath],[size_gb],[num_files],[num_folders]) VALUES (@fullpath, @size_gb, @num_files, @num_folders)" -f $global:config.config.sql.stagingtable);
	
	[void] $cmd.Parameters.Add("fullpath", [System.Data.SqlDbType] "NVarChar", 450);
	[void] $cmd.Parameters.Add("size_gb", [System.Data.SqlDbType] "Float");
	[void] $cmd.Parameters.Add("num_files", [System.Data.SqlDbType] "Int");
	[void] $cmd.Parameters.Add("num_folders", [System.Data.SqlDbType] "Int");
    
    # Full Path,Size,Allocated,Files,Folders,% of Parent,Last Change,Last Access    
	ForEach ($cur in $sizedata)
	{
        if ($cur -match "\*\.\*")
        {
            continue;        
        }
        
        $endpath = $cur.LastIndexOf("\");
        if ($endpath -gt -1)
        {
            $fullpath = $cur.Substring(0,$endpath);
            $remaining = $cur.Substring($endpath+1).Split(',',[System.StringSplitOptions]::"RemoveEmptyEntries");
            $size_gb = $remaining[0] -replace " GB", "";
            $num_files = $remaining[2];
            $num_folders = $remaining[3];

        	$cmd.Parameters["fullpath"].Value = $fullpath;
        	$cmd.Parameters["size_gb"].Value = $size_gb;
        	$cmd.Parameters["num_files"].Value = $num_files;
        	$cmd.Parameters["num_folders"].Value = $num_folders;
            
            [void] $cmd.ExecuteNonQuery();   
        }
	}
	
    $cmd.CommandType = [System.Data.CommandType] "Text";
	$cmd.CommandText = ("MERGE {0} AS dest
                        USING (SELECT [fullpath]
                              ,[size_gb]
                              ,[num_files]
                              ,[num_folders]
                        	FROM {1}
                        	WHERE [fullpath] = @path OR [fullpath] LIKE @path + '\%') AS src ([fullpath],[size_gb],[num_files],[num_folders])
                        ON (dest.[fullpath] = src.[fullpath])
                        WHEN MATCHED 
                            THEN UPDATE SET [size_gb] = src.[size_gb],
                        				[num_files] = src.[num_files],
                        				[lastupdated] = GETDATE()
                        WHEN NOT MATCHED BY TARGET
                        	THEN INSERT ([fullpath],[size_gb],[num_files],[num_folders],[lastupdated])
                        	VALUES (src.[fullpath],src.[size_gb],src.[num_files],src.[num_folders],GETDATE())
                        WHEN NOT MATCHED BY SOURCE AND (dest.[fullpath] = @path OR dest.[fullpath] LIKE @path + '\%')
                        	THEN DELETE;" -f $global:config.config.sql.table, $global:config.config.sql.stagingtable);
    [Void] $cmd.Parameters.Clear();
	[void] $cmd.Parameters.Add("path", [System.Data.SqlDbType] "NVarChar", 450);
    $cmd.Parameters["path"].Value = $path;
	
	[void] $cmd.ExecuteNonQuery(); 
    
	$conn.Close();
}



<#
Makes call to SQL post importing
#>
function Execute-PostCommand()
{
    if ($global:config.config.sql.postcmd -ne $null)
    {
    	Write-Output "Executing post command";

    	$conn = Create-SqlConnection;
        $cmd = New-Object System.Data.SqlClient.SqlCommand
        $cmd.Connection = $conn;
    	$cmd.CommandType = [System.Data.CommandType] "Text";
    	$cmd.CommandText = $global:config.config.sql.postcmd;
    	
        $cmd.CommandTimeout = 0;
        
    	[Void] $cmd.ExecuteNonQuery();
        
    	Write-Output "Post command finished";
    }        
}


Clear;

Write-Output "Starting";

Load-Config $configfile;

ForEach($share in $global:config.config.shares.share)
{
	$depth = $global:defaultdepth;

	if ($share.GetType() -eq [System.Xml.XmlElement])
	{
		$path = $share.'#text';
		$depth = $share.depth;
	}
	else
	{
		$path = $share;
	}

	try
	{
		$csvfile = Run-TreeSize $global:config.config.treesize.exe $global:config.config.treesize.arguments $path $depth

	}
	catch
	{
		Write-Output $_.Exception.Message -iserror $true;
        Break;
	}

	Save-ResultsToSQL $csvfile $path;
}


Execute-PostCommand


Write-Output "Complete";