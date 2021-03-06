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

alter table dcbs add st_num_dict_orig bigint
alter table dcbs add st_num_dict_conv bigint
go


alter table dcbs drop column st_qc_conv_report_results_ttl 
go
alter table dcbs add st_qc_conv_report_results_manual int
go
alter table dcbs add st_qc_conv_report_results_ttl 
AS (case when st_qc_conv_report_results_manual is not null then st_qc_conv_report_results_manual  else st_qc_conv_report_results end)
go 

alter table dcbs add st_qc_conv_report_results_manual int
go
alter table dcbs add st_qc_conv_report_results_ttl 
AS (case when st_qc_conv_report_results_manual is not null then st_qc_conv_report_results_manual  else st_qc_conv_report_results end)
go

alter table dcbs add st_qc_compare_tags_results_manual int
go
alter table dcbs add st_qc_compare_tags_results_ttl 
AS (case when st_qc_compare_tags_results_manual is not null then st_qc_compare_tags_results_manual  else st_qc_compare_tags_results end)
go

alter table dcbs add st_qc_compare_dict_results_manual int
go
alter table dcbs add st_qc_compare_dict_results_ttl 
AS (case when st_qc_compare_dict_results_manual is not null then st_qc_compare_dict_results_manual  else st_qc_compare_dict_results end)
go

alter table dcbs add st_qc_all_reports_manual int
go

alter table dcbs add st_all_manual int
go



