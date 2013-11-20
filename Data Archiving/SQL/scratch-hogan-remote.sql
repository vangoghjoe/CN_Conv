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

select * from DCBs where images_folders_bytes is not null

alter table DCBs alter column images_folders_bytes as 


select * from folders where dbid = 5

-- 10/7/13  -- yields 11 recs, they're all ok
select dbid,clientmatter, batchid, btba, conv_dcb, orig_dcb,db_bytes, natives_folders_bytes, images_folders_bytes FROM DCBs 
WHERE bReadyForArchive = 1 and natives_folders_bytes = 0 and images_folders_bytes = 0 and bCMClosed = 0


select dbid,clientmatter, batchid, btba, conv_dcb, orig_dcb,db_bytes, natives_folders_bytes, images_folders_bytes FROM DCBs 
WHERE bReadyForArchive = 1 and natives_folders_bytes = 0 and images_folders_bytes = 0 and bCMClosed = 1

select * FROM DCBs 
WHERE bReadyForArchive = 1 and natives_folders_bytes = 0 and images_folders_bytes = 0 and bCMClosed = 0
SELECT * from dcbs where orig_dcb like '%innovat%'
SELECT * from dcbs where orig_dcb like '%-notes%'

-- 10/7 Create DCB_Files
DROP TABLE DCB_files
CREATE TABLE DCB_Files(id int IDENTITY, dbid int, name varchar(100),
bOrig_exists bit, orig_bytes bigint, bConv_exists bit, conv_bytes bigint,
orig_pfn varchar(300), conv_pfn varchar(300))

select * from DCBs where st_backup_arch = 2 and dbid in 
(SELECT DISTINCT(dbid) from DCB_Files where bOrig_exists = 0)

-- 10/7 slipped thru: backup status bad but still has DBFolderInfoComplete
SELECT * from DCBs WHERE st_backup_arch <> 2 and (bDBFolderInfoComplete = 1)

-- 10/7 bkup problems: just diff in size.  About a hundred, confirmed by inspection that all are ok 
select * from DCB_Files WHERE 
bconv_exists = 1 and
borig_exists = 1 and 
(abs(orig_bytes - conv_bytes) > 100)

-- T 10/8 have to worry about 
select distinct(clientmatter) from DCBs where bReadyForArchive = 1 and bCMClosed = 0 ORDER BY clientmatter -- just 

select distinct(clientmatter) from DCBs where bReadyForArchive = 1 and bCMClosed = 0 
and clientmatter in (
select distinct(db.clientmatter) from 
DCBs db join
DCB_Files f 
on db.dbid = f.dbid
WHERE 
f.bconv_exists = 0
ORDER BY db.clientmatter  -- this inner query by itself gives the problem CM's
)
-- 65 matters had the backup problem
-- 174 dbs had backup problems
-- there are 55 open clientmatters that have a db that is RTBA.
-- BUT, they only have one CM in common: 063553.000160  Double checked by 