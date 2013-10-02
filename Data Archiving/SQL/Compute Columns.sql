
-- *** 
-- Init
-- Compute
-- Report

--********************************************************************************
-- *** CM.bCMClosed
-- Init
IF EXISTS(select * from sys.columns where name = 'bCMClosed' and object_id=object_id('ClientMattersTBA'))
	ALTER TABLE ClientMattersTBA DROP COLUMN bCMClosed
GO
ALTER TABLE ClientMattersTBA ADD bCMClosed bit
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
IF EXISTS(select * from sys.columns where name = 'bCMClosed' and object_id=object_id('DCBs'))
	ALTER TABLE DCBs DROP COLUMN bCMClosed
GO
ALTER TABLE DCBs ADD bCMClosed bit
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

      -- if any aren't children arent' complete, it's not
      IF EXISTS (
		SELECT * FROM DCBs WHERE 
			clientmatter = @clientmatter
			AND 
			bDBFolderInfoComplete <> 1  -- safe b/c no nulls
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
--********************************************************************************
-- *** DCB.bReadyForArchive
-- Init
if not exists(
	select * from sys.columns 
    where Name = 'bReadyForArchive' and Object_ID = Object_ID('DCBs'))
BEGIN
	ALTER TABLE DCBs ADD bReadyForArchive bit
END
GO
UPDATE DCBs set bReadyForArchive = 0
GO	
	           
-- Compute
--  ++++  CASE 1: in a closed matter ++++
UPDATE DCBs SET bReadyForArchive = 1 WHERE bCMClosed = 1
GO

--  ++++  CASE 2: in an open matter ++++
DECLARE @dbid int;

DECLARE mycursor CURSOR FOR
	SELECT dbid FROM DCBs
	WHERE isnull(bCMClosed,0) = 0
OPEN mycursor;

FETCH NEXT FROM mycursor INTO @dbid
WHILE @@FETCH_STATUS = 0
BEGIN
	IF EXISTS (
		SELECT * FROM DCBs 
		WHERE 
			dbid = @dbid AND 
			bTBA = 1 AND
			bdbfolderinfocomplete = 1 AND
			isnull(bHasOverlaps,1) = 0  --hmm, null = 0 would fail, so probably don't need isnull()
	)
	BEGIN
		UPDATE DCBs set bReadyForArchive = 1
	END			
	FETCH NEXT FROM mycursor INTO @dbid
END
CLOSE mycursor

DEALLOCATE mycursor
GO
-- Report
SELECT COUNT(*) AS 'DCBs . num bReadyForArchive' 
FROM DCBs
WHERE bReadyForArchive = 1
GO

-- *** 
-- Init
-- Compute
-- Report

--********************************************************************************
-- ** number of CM's
SELECT COUNT(*) AS 'Num CMs' FROM ClientMattersTBA

--********************************************************************************
-- ** number of DCBs with overlaps
SELECT COUNT(*) AS 'DBs with Overlaps' FROM DCBs where bHasOverlaps = 1

