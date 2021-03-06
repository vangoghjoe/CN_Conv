-- Su 9/30 (in the wee hours
--alter table dcbs
--ADD bTBA bit

--update dcbs set btba = 1 where batchid = 3
--update dcbs set btba = 0 where batchid = 4

--alter table dcbs add bDBFolderInfoComplete as
--case 
--WHEN isnull(st_get_folders_natives,0) = 2 AND isnull(st_get_folders_images,0) = 2 
--  THEN 1
--ELSE 0
--END

--SELECT st_get_folders_images, st_get_folders_natives, bDBFolderInfoComplete from DCBs

 --select * from ErrorsScript
 --WHERE CMClosed is null

 --alter table dcbs add bCMClosed bit

--UPDATE 
--	d
--SET 
--	d.bcmclosed = (CASE e.cmclosed WHEN 'XX' THEN 1 ELSE 0 END)
--FROM
--	DCBs d
--	JOIN 
--	ErrorsScript e ON d.dbid = e.DBID

--select count(*)
--FROM
--	DCBs d
--	JOIN 
--	ErrorsScript e ON d.dbid = e.DBID
-- --> 117

--SELECT * FROM ErrorsScript 
--WHERE dbid not in 
--(SELECT dbid from DCBs)
--  -> AH, these were from the dupes in NA that were also in TBA that I removed. Whew!

--ALTER TABLE clientmattersTBA ADD bCMClosed bit

--UPDATE ClientMattersTBA
--SET bCMClosed = 1
--WHERE ClientMatter in 
--(SELECT DISTINCT(clientmatter)
--FROM DCBS
--WHERE bCMClosed = 1)

--SELECT DISTINCT(clientmatter)
--FROM ClientMattersTBA
--WHERE bCMClosed = 1

--ALTER TABLE DCBS ADD bHasOverlaps BIT

-- Seems like can *almost* do it with rel ops, but not quite
--UPDATE d
--SET d.bHasOverlaps = (
--CASE
--WHEN EXISTS (
--	SELECT * from Folders f WHERE b 

-- alter table folders alter column clientmatter varchar(25)

-- Added indices on folders::dbid and clientmatter

-- *****************************************************************************
--  CALC DCBs::bHasOverlaps
-- running at 4:30A Mon morning


--declare @dcbs table (dbid int, clientmatter varchar(2), bHasOverlaps bit);
--declare @folders table (dbid int, clientmatter varchar(2), folder varchar(25)); 

--insert into @dcbs values (1, 'a', null);
--insert into @dcbs values (2, 'a', null);
--insert into @dcbs values (3, 'b', null);

--insert into @folders values(1, 'a', 'f1');
--insert into @folders values(2, 'a', 'f2');
--insert into @folders values(11, 'a', 'f1');
--insert into @folders values(3, 'b', 'fb3');
--insert into @folders values(4, 'b', 'fb3');

--select * from @dcbs;
--select * from @folders;

--DECLARE @dbid int;
--DECLARE @clientmatter varchar(25);
--DECLARE @has_overlap BIT;
--DECLARE @cmNum int;
--DECLARE @myDate as varchar(30);
--DECLARE mycursor CURSOR FOR
--  SELECT dbid, clientmatter
--  FROM   DCBs
--	WHERE btba = 1
--	AND bDBFolderInfoComplete = 1
--    AND isnull(bCMClosed,0) = 0
--	AND bHasOverlaps is null

--OPEN mycursor;

--FETCH NEXT FROM mycursor INTO @dbid, @clientmatter
--set @cmNum = 0
--WHILE @@FETCH_STATUS = 0
--  BEGIN
--      SET @cmNum = @cmNum + 1
--      SET @myDate = convert(varchar, GETDATE()) + ' ' + convert(varchar, @cmnum) 
--      SET @myDate = @myDate + ' ' + convert(varchar, @dbid); 
--      RAISERROR( @mydate ,0,1) WITH NOWAIT;
--      IF EXISTS (SELECT folder
--                 FROM   Folders
--                 WHERE  ClientMatter = @clientmatter
--                        AND dbid = @dbid
--                 INTERSECT
--                 SELECT folder
--                 FROM   Folders
--                 WHERE  ClientMatter = @clientmatter
--                        AND dbid != @dbid
--                        )
--        SET @has_overlap = 1;
--      ELSE
--        SET @has_overlap = 0;

--      UPDATE DCBs
--      SET    bHasOverlaps = @has_overlap
--      WHERE  dbid = @dbid

--      FETCH NEXT FROM mycursor INTO @dbid, @clientmatter
--  END

--CLOSE mycursor

--DEALLOCATE mycursor

--select * from dcbs;

-- *******************************************
 -- SELECT dbid, clientmatter
 -- FROM   DCBs
	--WHERE btba = 1
	--AND bDBFolderInfoComplete = 1
 --   AND isnull(bCMClosed,0) = 0
	--AND bHasOverlaps is null
--  --> 408
-- *******************************************
--select distinct(btba) from dcbs where bCMClosed = 1
--select * from ErrorsScript where TBA = 'xx' and CMClosed = 'xx'

select * from ClientMattersTBA where bCMClosed = 1
select distinct(ClientMatter) from DCBs
select distinct(clientmatter) from ErrorsScript where CMClosed is not null

 
--SELECT DISTINCT(clientmatter) from ErrorsScript where CMClosed is not null
--AND clientmatter not in 
--(select distinct(clientmatter) from dcbs)
-- --> 0  So, just a dbchk that we can match on all the CMs in the error list
----  So now, can update the 
--SELECT DISTINCT(clientmatter) from ErrorsScript where CMClosed is not null
--AND clientmatter not in 
--(select distinct(clientmatter) from ClientMattersTBA)
-- -> 0 Just another check

 update DCBs set bCMClosed = 1 
 where clientmatter in
 (SELECT DISTINCT(clientmatter) from ErrorsScript where CMClosed is not null)
 -- --> 408 rows

  update ClientMattersTBA set bCMClosed = 1 
 where clientmatter in
 (SELECT DISTINCT(clientmatter) from ErrorsScript where CMClosed is not null)

 -- Talked to Jesse, he says if a CM is closed, mark all it's db's for archiving
 -- Just for the heck of it, save the old TBA value, pre-closed-CM update
 --alter table dcbs add TBA_orig bit
 --exec sp_rename 'dcbs.tba_orig','bTBA_orig', 'column'
 
 --update dcbs set bTBA_orig = bTBA

 update DCBs set bCMClosed = 1 where clientmatter in
 (select distinct(clientmatter) from ClientMattersTBA where bCMClosed = 1)

 select 
 (select distinct(clientmatter) from ClientMattersTBA where bCMClosed = 1)

 exec sp_rename 'clientmatterstba.alldbs_analysisIsGood','bCMFolderInfoComplete','column'
 select * from DCBs where bDBFolderInfoComplete is null