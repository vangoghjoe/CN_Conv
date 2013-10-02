
-- *** 
-- Init
-- Compute
-- Report

-- *** CM.bCMClosed
-- Init
-- ALTER TABLE clientMattersTBA add bCMClosed bit
UPDATE ClientMattersTBA SET bCMClosed = 0
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
      WHERE  ClientMatter = @clientmatter

      FETCH NEXT FROM mycursor INTO @clientmatter
  END

CLOSE mycursor

DEALLOCATE mycursor
-- Report
SELECT COUNT(*) as 'CM.bCMFolderInfoComplete' FROM ClientMattersTBA 
WHERE bCMFolderInfoComplete = 1

-- *** DCB.bReadyForArchive
-- Init
if not exists(select * from sys.columns 
            where Name = 'bReadyForArchive' and Object_ID = Object_ID('DCBs'))
	ALTER TABLE DCBs ADD bReadyForArchive bit
UPDATE DCBs set bReadyForArchive = 0
	
	           
-- Compute
UPDATE DCBs SET bReadyForArchive = 1 WHERE bCMClosed = 1

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

-- Initialize all to 0 first
UPDATE DCBs SET bReadyForArchive = 0

DECLARE mycursor CURSOR FOR
	SELECT dbid, clientmatter FROM DCBs
OPEN mycursor;

FETCH NEXT FROM mycursor INTO @dbid, @clientmatter
set @cmNum = 0
WHILE @@FETCH_STATUS = 0
  BEGIN
      SET @cmNum = @cmNum + 1
      SET @myDate = convert(varchar, GETDATE()) + ' ' + convert(varchar, @cmnum) 
      SET @myDate = @myDate + ' ' + convert(varchar, @dbid); 
      RAISERROR( @mydate ,0,1) WITH NOWAIT;

	  if EXISTS(
		select * from ClientMattersTBA where ClientMatter = @clientmatter and bCMclosed = 1		
	  )
		BEGIN
			IF EXISTS (
				SELECT * FROM DCBs 
				WHERE 
				dbid = @dbid AND 
				btba_orig = 1 AND
				bdbfolderinfocomplete = 1
				isnull(bhas_overlaps,1) = 0  --hmm, null = 0 would fail, so probably don't need isnull()
			)
				UPDATE DCBs set bReadyForArchive = 1
      FETCH NEXT FROM mycursor INTO @clientmatter
  END

CLOSE mycursor

DEALLOCATE mycursor
-- Report

-- *** 
-- Init
-- Compute
-- Report

-- ** number of CM's
SELECT COUNT(*) AS 'Num CMs' FROM ClientMattersTBA

-- ** number of DCBs with overlaps
SELECT COUNT(*) AS 'DBs with Overlaps' FROM DCBs where bHasOverlaps = 1

