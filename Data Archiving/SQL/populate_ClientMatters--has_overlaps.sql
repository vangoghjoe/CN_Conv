USE Hogan_Data_Archiving

DECLARE @clientmatter NVARCHAR(30);
DECLARE @has_overlap BIT;
DECLARE mycursor CURSOR FOR
  SELECT clientmatter
  FROM   clientmatters;

OPEN mycursor;

FETCH NEXT FROM mycursor INTO @clientmatter

WHILE @@FETCH_STATUS = 0
  BEGIN
	  PRINT @clientmatter
      IF EXISTS (SELECT folder
                 FROM   Folders
                 WHERE  ClientMatter = @clientmatter
                        AND TBA = 0
                 INTERSECT
                 SELECT folder
                 FROM   Folders
                 WHERE  ClientMatter = @clientmatter
                        AND TBA = 1
                        )
        SET @has_overlap = 1;
      ELSE
        SET @has_overlap = 0;

      UPDATE ClientMatters
      SET    has_overlaps = @has_overlap
      WHERE  ClientMatter = @clientmatter

      FETCH NEXT FROM mycursor INTO @clientmatter
  END

CLOSE mycursor

DEALLOCATE mycurso