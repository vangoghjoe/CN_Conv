 --********************************************************************************
 -- *** DCBs . bHasFoldersMissing
 -- Init
IF EXISTS(select * from sys.columns where name = 'bHasFoldersMissing' and object_id=object_id('DCBs'))
	UPDATE DCBs SET bHasFoldersMissing = null
ELSE	
	ALTER TABLE DCBs ADD bHasFoldersMissing bit

---- TEST DATA
--insert into DCBs (dbid) values (10001), (10002),(10003),(10004)
--insert into Folders	(DBID, bExists) values 
--(10001,0),
--(10002,-1),
--(10003,1),
--(10004,0),(10004,1)

 -- Compute
DECLARE @dbid int;
DECLARE @clientmatter varchar(25);
DECLARE @hasMissing BIT;
DECLARE @cmNum int;
DECLARE @myDate as varchar(30);
DECLARE mycursor CURSOR FOR
  SELECT dbid 
  FROM DCBs


OPEN mycursor;

FETCH NEXT FROM mycursor INTO @dbid
set @cmNum = 0
WHILE @@FETCH_STATUS = 0
  BEGIN
      SET @cmNum = @cmNum + 1
      SET @myDate = convert(varchar, GETDATE()) + ' ' + convert(varchar, @cmnum) 
      SET @myDate = @myDate + ' ' + convert(varchar, @dbid); 
      RAISERROR( @mydate ,0,1) WITH NOWAIT;
      
      IF EXISTS (
		SELECT * FROM Folders 
		WHERE DBID = @dbid
		  AND bExists = 0
	  ) 		  
        SET @hasMissing = 1;
      ELSE
        SET @hasMissing = 0;

      UPDATE DCBs
      SET    bHasFoldersMissing = @hasMissing
      WHERE  dbid = @dbid

      FETCH NEXT FROM mycursor INTO @dbid
  END
CLOSE mycursor
DEALLOCATE mycursor

---- TEST
--select dbid,bHasFoldersMissing from DCBs where dbid > 10000
--select dbid,bexists from Folders where DBID > 10000
--delete from DCBs where dbid > 10000
--delete from folders where dbid > 10000

-- Report
SELECT COUNT(*) AS 'DCBs.num HasFoldersMissing' 
FROM DCBs 
WHERE bHasFoldersMissing = 1