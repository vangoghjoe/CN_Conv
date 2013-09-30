CREATE TABLE ClientMattersTBA
  (
     ID                INT IDENTITY(1, 1) NOT NULL,
     ClientMatter      NVARCHAR(50),
     tba               BIT,
     analysis_complete BIT,
     has_overlaps      BIT
  ) 

TRUNCATE TABLE ClientMattersTBA
INSERT INTO ClientMattersTBA
            (ClientMatter)
SELECT DISTINCT( ClientMatter )
FROM   DCBs 
WHERE  batchid = 3

UPDATE ClientMattersTBA
SET    Tba = 1
