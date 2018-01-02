
declare @cmd nvarchar(max) = '';

select @cmd += 'exec msdb..sp_update_job @job_name='''+Identifier+''', @enabled=0;'+char(10)
from scheduler.Task
--print @cmd
exec sp_executesql @cmd;

set @cmd = ''

select @cmd+='exec msdb..sp_stop_job @job_name='''+t.Identifier+''';'+char(10)
from scheduler.Task t
join scheduler.CurrentlyExecutingTasks cet on cet.TaskId = t.TaskId;
--print @cmd
exec sp_executesql @cmd;
