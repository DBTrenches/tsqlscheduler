create or alter view scheduler.CurrentlyExecutingTasks
as

select      tasks.InstanceId
            ,tasks.TaskId
            ,tasks.ExecutionId
            ,r.session_id
from        sys.dm_exec_requests as r
cross apply (
    select try_cast(r.context_info as varchar(128)) as ContextInfo
) as i
cross apply openjson (i.ContextInfo, N'$')
    with (
        InstanceId      uniqueidentifier    N'$.i'
        ,Taskid         int                 N'$.t'
        ,ExecutionId    int                 N'$.e'
    ) as tasks
where   r.context_info <> 0x
and     isjson(i.ContextInfo) = 1