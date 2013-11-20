SELECT  *

FROM sys.dm_tran_locks

SELECT * FROM sys.dm_exec_requests

WHERE blocking_session_id > 0