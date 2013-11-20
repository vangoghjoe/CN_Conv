
-- *** 
-- Init
-- Compute
-- Report

--********************************************************************************
-- *** CM.bCMClosed
-- Init
IF NOT EXISTS(select * from sys.columns where name = 'bCMClosed' and object_id=object_id('ClientMattersTBA'))
	ALTER TABLE ClientMattersTBA ADD bCMClosed bit
GO
UPDATE ClientMattersTBA SET bCMClosed = 0
GO

-- Compute
 update ClientMattersTBA set bCMClosed = 1 
 where clientmatter in
 (SELECT DISTINCT(clientmatter) from ErrorsScript where CMClosed is not null)
GO
-- Report
SELECT COUNT(*) as 'CM.bCMClosed' FROM ClientMattersTBA WHERE bCMClosed = 1 
GO

--********************************************************************************
-- *** DCB.bCMClosed
-- Init
IF NOT EXISTS(select * from sys.columns where name = 'bCMClosed' and object_id=object_id('DCBs'))
	ALTER TABLE DCBs ADD bCMClosed bit
GO
UPDATE DCBs set bCMClosed = 0
GO

-- Compute
UPDATE DCBs SET bCMClosed = 1 WHERE clientmatter in
 (select distinct(clientmatter) from ClientMattersTBA where bCMClosed = 1)
GO 
--Report
SELECT COUNT(*) AS 'DCB.bCMClosed' FROM DCBs WHERE bCMClosed = 1 
GO

--********************************************************************************
-- *** DCB.bDBFolderInfoComplete
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
GO

--********************************************************************************
-- ***********  CM.bCMFolderInfoComplete
-- Init
IF NOT EXISTS(select * from sys.columns where name = 'bCMFolderInfoComplete' and object_id=object_id('ClientMattersTBA'))
	ALTER TABLE ClientMattersTBA ADD bCMFolderInfoComplete bit
GO

UPDATE ClientMattersTBA SET bCMFolderInfoComplete = 0
GO

-- Compute
-- Calc CM.bCMFolderInfoComplete
DECLARE @isComplete int;
DECLARE @clientmatter varchar(25);
DECLARE mycursor CURSOR FOR
SELECT ClientMatter FROM ClientMattersTBA

OPEN mycursor;

FETCH NEXT FROM mycursor INTO @clientmatter

WHILE @@FETCH_STATUS = 0
  BEGIN

      -- if any children arent' complete, or if it has any missing/malformed folders,
	  -- it's not complete
      IF EXISTS (
		SELECT * FROM DCBs WHERE 
			clientmatter = @clientmatter
			AND 
			(bDBFolderInfoComplete <> 1  -- safe b/c no nulls
			OR isnull(bHasFoldersMalformed,0) = 1
			OR isnull(bHasFoldersMissing,0) = 1
			)
	  )
        SET @isComplete = 0;
      ELSE
        SET @isComplete = 1;

      UPDATE ClientMattersTBA
      SET    bCMFolderInfoComplete = @isComplete
      WHERE  ClientMatter = @clientmatter

      FETCH NEXT FROM mycursor INTO @clientmatter
  END

CLOSE mycursor

DEALLOCATE mycursor
GO

-- Report
SELECT COUNT(*) as 'CM.bCMFolderInfoComplete' FROM ClientMattersTBA 
WHERE bCMFolderInfoComplete = 1
GO




