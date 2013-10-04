 --********************************************************************************
 -- *** DCBs . bHasFoldersMalformed
 -- Init
IF EXISTS(select * from sys.columns where name = 'bHasFoldersMalformed' and object_id=object_id('DCBs'))
	ALTER TABLE DCBs DROP COLUMN bHasFoldersMalformed
GO
ALTER TABLE DCBs ADD bHasFoldersMalformed bit
GO

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

DECLARE mycursor CURSOR FOR
  SELECT dbid 
  FROM DCBs
OPEN mycursor;
FETCH NEXT FROM mycursor INTO @dbid
WHILE @@FETCH_STATUS = 0
  BEGIN     
      IF EXISTS (
		SELECT * FROM Folders 
		WHERE DBID = @dbid
		  AND bExists = -1
	  ) 		  
        SET @hasMissing = 1;
      ELSE
        SET @hasMissing = 0;

      UPDATE DCBs
      SET    bHasFoldersMalformed = @hasMissing
      WHERE  dbid = @dbid

      FETCH NEXT FROM mycursor INTO @dbid
  END
CLOSE mycursor
DEALLOCATE mycursor

---- TEST
--select dbid,bHasFoldersMalformed from DCBs where dbid > 10000
--select dbid,bexists from Folders where DBID > 10000
--delete from DCBs where dbid > 10000
--delete from folders where dbid > 10000

-- Report
SELECT COUNT(*) AS 'DCBs.num bHasFoldersMalformed' 
FROM DCBs 
WHERE bHasFoldersMalformed = 1
