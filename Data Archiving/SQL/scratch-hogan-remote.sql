select dbid, db_bytes,db_files FROM DCBs where bReadyForArchive = 1

select * from DCBs ORDER BY DBID OFFSET 0 ROWS FETCH NEXT 5 ROWS ONLY 
UPDATE folders set bytes = null, files = null

SELECT * from ClientMattersTBA WHERE (tba <>1 or tba is null)
SELECT * from ClientMattersTBA WHERE (bCMClosed = 1)

-- Sa 10/5
CREATE TABLE ClientMattersClosed1004 (ID int IDENTITY, Client varchar(15), matter varchar(15), clientmatter as client + '.' + matter)
CREATE TABLE paste(first varchar(10), last varchar(10))
truncate table ClientMattersClosed1004
select * from ClientMattersClosed1004 WHERE clientmatter not in (
select distinct(clientmatter) from ClientMattersTBA)
select * from ClientMattersTBA where clientmatter like '%003540%' or clientmatter like '%081400%'

CREATE TABLE DCBs_On_X_20131005 (ID int IDENTITY, orig_dcb varchar(max), clientmatter varchar(50))
SELECT * FROM DCBs_On_X_20131005

SELECT * FROM DCBs WHERE clientmatter not in (select distinct(clientmatter) from ClientMattersTBA) 
-- yields one dcb, dbid = 1358, with clientmatter  = 061540

SELECT distinct(clientmatter) FROM DCBs_On_X_20131005 WHERE clientmatter in 
(select clientmatter from DCBs where btba = 1 AND bCMClosed = 0 and bReadyForArchive = 1) 
AND orig_dcb not in (SELECT orig_dcb FROM DCBs) 

SELECT * from DCBs WHERE clientmatter = '061540_CLIENT.000013'
-- 15 rows.  Some are have recent dates in them, but for the others, no way to be sure

select * into DCBs1006 from DCBs

-- 10/7/ 11A PST Add in new clientmatters from Jesse's list from Fri
-- -> 2 new cms'
insert into ClientMattersTBA (clientmatter)
select distinct(clientmatter) from ClientMattersClosed1004 WHERE clientmatter not in (
select distinct(clientmatter) from ClientMattersTBA)

-- 
select * from DCBs_On_X_20131005 where (
clientmatter in 
	(select clientmatter from ClientMattersTBA )
AND
orig_dcb not in 
	(select orig_dcb from dcbs)
)
-- yields 15 rows.  