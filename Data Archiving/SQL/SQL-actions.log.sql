*****************
Su 9/30 1AM
/* 
First had to delete the quotes.
Also, chagned the exponential notaion to numbers
Then, got error about st_all, which is last in CSV.  So, deleted the fields in the DB that were after that, and the import worked
*/
truncate table DCBs;
go

bulk insert DCBs
FROM 'W:\_LN_Test\Conversion_Admin\DB\DCBs - for import.txt'
WITH (
  fieldterminator = '\t',
  firstrow = 2
)

go
select * from DCBs

********************
alter table dcbs
ADD bTBA bit

update dcbs set btba = 1 where batchid = 3
update dcbs set btba = 0 where batchid = 4

alter table dcbs add bDBFolderInfoComplete as
case 
WHEN isnull(st_get_folders_natives,0) = 2 AND isnull(st_get_folders_images,0) = 2 
  THEN 1
ELSE 0
END

