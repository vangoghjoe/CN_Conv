
-- *** 
-- Init
-- Compute
-- Report

-- *** CM.bCMClosed
-- Init
UPDATE bCMClosed FROM ClientMattersTBA SET bCMClosed = 0
-- Compute
 update ClientMattersTBA set bCMClosed = 1 
 where clientmatter in
 (SELECT DISTINCT(clientmatter) from ErrorsScript where CMClosed is not null)
-- Report
SELECT COUNT(*) as 'CM.bCMClosed' FROM ClientMattersTBA WHERE bCMClosed = 1 

-- *** DCB.bCMClosed
-- Init
UPDATE DCBs SET bCMClosed = 0 
-- Compute
UPDATE DCBs SET bCMClosed = 1 WHERE clientmatter in
 (select distinct(clientmatter) from ClientMattersTBA where bCMClosed = 1)
--Report
SELECT COUNT(*) AS 'DCB.bCMClosed' FROM DCBs WHERE bCMClosed = 1 

-- *** DCB.bFolderInfoComplete
-- Init
-- Compute
----- It's a computed field, nothing to compute
----alter table dcbs add bDBFolderInfoComplete as
----case 
----WHEN isnull(st_get_folders_natives,0) = 2 AND isnull(st_get_folders_images,0) = 2 
----  THEN 1
----ELSE 0
----END

-- Report
SELECT COUNT(*) AS 'DCB.bDBFolderInfoComplete' FROM DCBs WHERE bDBFolderInfoComplete = 1 

-- *** CM.bCMFolderInfoComplete
-- Init
UPDATE ClientMattersTBA SET bCMFolderInfoComplete = 0
-- Compute
-- Calc CM.bCMFolderInfoComplete
DECLARE @dbid int;
DECLARE @clientmatter varchar(25);
DECLARE @isComplete BIT;
DECLARE @cmNum int;
DECLARE @myDate as varchar(30);
DECLARE mycursor CURSOR FOR
SELECT ClientMatter FROM ClientMattersTBA

OPEN mycursor;

FETCH NEXT FROM mycursor INTO @clientmatter
set @cmNum = 0
WHILE @@FETCH_STATUS = 0
  BEGIN
      SET @cmNum = @cmNum + 1
      SET @myDate = convert(varchar, GETDATE()) + ' ' + convert(varchar, @cmnum) 
      SET @myDate = @myDate + ' ' + convert(varchar, @dbid); 
      RAISERROR( @mydate ,0,1) WITH NOWAIT;
      -- if any aren't children arent' complete, it's not
      IF EXISTS (
		SELECT * FROM DCBs WHERE 
			clientmatter = @clientmatter
			AND 
			bdbFolderInfoComplete <> 1  -- safe b/c no nulls
	  )
        SET @isComplete = 0;
      ELSE
        SET @isComplete = 1;

      UPDATE ClientMattersTBA
      SET    bCMFolderInfoComplete = @isComplete
      WHERE  ClientMatter = @dbid

      FETCH NEXT FROM mycursor INTO @clientmatter
  END

CLOSE mycursor

DEALLOCATE mycursor
-- Report
SELECT COUNT(*) as 'CM.bCMFolderInfoComplete' FROM ClientMattersTBA 
WHERE bCMFolderInfoComplete = 1

-- *** 
-- Init
-- Compute
-- Report

-- *** 
-- Init
-- Compute
-- Report