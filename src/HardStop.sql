
declare @cmd nvarchar(max) = '';

select @cmd += 'exec msdb..sp_update_job @job_name='''+ t.Identifier+''', @enabled=0;'+char(10)
from scheduler.AgentJobsForCurrentInstance as i
join scheduler.Task as t
on t.TaskUid = i.TaskUid
--print @cmd
exec sp_executesql @cmd;

set @cmd = ''

select @cmd+='exec msdb..sp_stop_job @job_name='''+t.Identifier+''';'+char(10)
from scheduler.Task t
join scheduler.CurrentlyExecutingTasks cet on cet.TaskId = t.TaskId;
--print @cmd
exec sp_executesql @cmd;
