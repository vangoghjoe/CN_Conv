 *** bHasFoldersMissing
 Init
 Compute
 Report
DECLARE @dbid int;
DECLARE @clientmatter varchar(25);
DECLARE @has_overlap BIT;
DECLARE @cmNum int;
DECLARE @myDate as varchar(30);
DECLARE mycursor CURSOR FOR
  SELECT dbid, clientmatter
  FROM   DCBs
	WHERE btba = 1
	AND bDBFolderInfoComplete = 1
    AND isnull(bCMClosed,0) = 0
	AND bHasOverlaps is null

OPEN mycursor;

FETCH NEXT FROM mycursor INTO @dbid, @clientmatter
set @cmNum = 0
WHILE @@FETCH_STATUS = 0
  BEGIN
      SET @cmNum = @cmNum + 1
      SET @myDate = convert(varchar, GETDATE()) + ' ' + convert(varchar, @cmnum) 
      SET @myDate = @myDate + ' ' + convert(varchar, @dbid); 
      RAISERROR( @mydate ,0,1) WITH NOWAIT;
      IF EXISTS (SELECT folder
                 FROM   Folders
                 WHERE  ClientMatter = @clientmatter
                        AND dbid = @dbid
                 INTERSECT
                 SELECT folder
                 FROM   Folders
                 WHERE  ClientMatter = @clientmatter
                        AND dbid != @dbid
                        )
        SET @has_overlap = 1;
      ELSE
        SET @has_overlap = 0;

      UPDATE DCBs
      SET    bHasOverlaps = @has_overlap
      WHERE  dbid = @dbid

      FETCH NEXT FROM mycursor INTO @dbid, @clientmatter
  END

CLOSE mycursor

DEALLOCATE mycursor