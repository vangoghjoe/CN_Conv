CREATE TABLE ClientMatters
  (
     ID                INT IDENTITY(1, 1) NOT NULL,
     ClientMatter      NVARCHAR(50),
     tba               BIT,
     analysis_complete BIT,
     has_overlaps      BIT
  ) 

TRUNCATE TABLE ClientMatters
INSERT INTO ClientMatters
            (ClientMatter)
SELECT DISTINCT( ClientMatter )
FROM   DCBs 
WHERE  batchid = 3

UPDATE ClientMatters
SET    Tba = 1