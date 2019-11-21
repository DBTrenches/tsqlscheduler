create or alter view scheduler.AgentJobsForCurrentInstance
as
select j.job_id
      ,jobInfo.TaskUid
from msdb.dbo.sysjobs as j
cross apply openjson (j.description, N'$')
    with (
        InstanceId      uniqueidentifier    N'$.instanceId'
        ,TaskUid        uniqueidentifier    N'$.taskUid'
    ) as jobInfo
cross apply scheduler.GetInstanceId() as iid
where isjson(j.description) = 1
and jobInfo.InstanceId = iid.id