USE Hogan_Data_Archiving

DECLARE @clientmatter NVARCHAR(30);
DECLARE @allDBs_AnalysisIsGood BIT;
declare @cmNum int;

DECLARE mycursor CURSOR FOR
  SELECT clientmatter
  FROM   clientmattersTBA;

OPEN mycursor;

FETCH NEXT FROM mycursor INTO @clientmatter
SET @cmNum = 0
WHILE @@FETCH_STATUS = 0
  BEGIN
	 SET @cmNum = @cmNum + 1
	 PRINT @clientmatter
	 print @cmnum
      IF EXISTS (
		SELECT * from DCBs where clientmatter = @clientmatter AND ISNULL(analysisIsGood,0) != 1
		)
        SET @allDBs_AnalysisIsGood = 0;
      ELSE
        SET @allDBs_AnalysisIsGood = 1;

      UPDATE ClientMattersTBA
      SET    allDBs_AnalysisIsGood = @allDBs_AnalysisIsGood
      WHERE  ClientMatter = @clientmatter

      FETCH NEXT FROM mycursor INTO @clientmatter
  END

CLOSE mycursor

DEALLOCATE mycursor

select * from Clientmatterstba

