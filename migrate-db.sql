use [FYI_Conversions]

alter table [dbo].dcbs add st_backup_local_v8 int

go

alter table dcbs add st_qc_conv_report int
alter table dcbs add st_qc_conv_report_results int
go

alter table dcbs add st_num_recs_orig bigint
alter table dcbs add st_num_recs_conv bigint
go

alter table dcbs add conv_duration float
alter table dcbs add conv_start nvarchar(25)
alter table dcbs add conv_stop nvarchar(25)
go