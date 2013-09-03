USE [FYI_Conversions]
GO

/****** Object:  Table [dbo].[DCBs old]    Script Date: 09/02/2013 11:43:09 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[DCBs](
[batchid] [int] NULL,
[dbid] [int] NULL,
[clientid] [int] NULL,
[loadnr] [int] NULL,
[orig_dcb] [nvarchar] (max) NULL,
[conv_dcb] [nvarchar] (max) NULL,
[orig_dir] [nvarchar] (max) NULL,
[backup_done] [int] NULL,
[db_bytes] [int] NULL,
[db_files] [int] NULL,
[natives_bytes] [int] NULL,
[natives_files_present] [int] NULL,
[natives_files_missing] [int] NULL,
[images_bytes] [int] NULL,
[images_files_present] [int] NULL,
[image_files_missing] [int] NULL,
[st_backup] [int] NULL,
[st_get_images] [int] NULL,
[st_get_images2] [int] NULL,
[st_get_natives] [int] NULL,
[st_qc_tags] [int] NULL,
[st_qc_compare_tags] [int] NULL,
[st_backup_arch] [int] NULL,
[st_convert] [int] NULL,
[st_get_arch_db_files] [int] NULL,
[funky] [nvarchar] (max) NULL,
[st_add_images] [int] NULL,
[st_add_natives] [int] NULL,
[st_add_db] [int] NULL

) ON [PRIMARY]

GO



