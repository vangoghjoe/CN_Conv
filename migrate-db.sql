use [FYI_Conversions]

alter table [dbo].dcbs add st_backup_local_v8 int
select * from DCBs d where d.st_qc_compare_tags is null