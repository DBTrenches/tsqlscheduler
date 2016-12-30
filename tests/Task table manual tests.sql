INSERT INTO scheduler.Task
           (Identifier
           ,TSQLCommand
           ,StartTime
           ,FrequencyType
           ,FrequencyInterval
           ,NotifyOnFailureOperator)
     VALUES
    ('testJob'
    ,'select @@servername'
    ,'00:00'
    ,1
    ,5
    ,'Test Operator')
	,('testJob 2'
    ,'select @@servername'
    ,'00:00'
    ,1
    ,5
    ,'Test Operator')
GO
update scheduler.task set Identifier = 'test job 2' where identifier = 'testJob 2';
update scheduler.task set FrequencyType = 2 where Identifier = 'test job 2';
update scheduler.task set FrequencyType = 3 where Identifier = 'test job 2';
update scheduler.task set FrequencyType = 1 where Identifier = 'test job 2';
update scheduler.task set FrequencyInterval = 0 where FrequencyTypeDesc = 'Day'
go
select *
from scheduler.Task;

select *
from scheduler.TaskHistory;

select *
from scheduler.task for system_time all
order by TaskId asc, SysStartTime asc;
go
exec scheduler.CreateJobFromTask @identifier = 'testJob', @overwriteExisting = 1;
exec scheduler.CreateJobFromTask @identifier = 'test job 2', @overwriteExisting = 1;
go
update scheduler.task set FrequencyType = 2, FrequencyInterval = 10 where Identifier = 'test job 2';
exec scheduler.CreateJobFromTask @identifier = 'test job 2', @overwriteExisting = 1;
go
update scheduler.task set FrequencyType = 3, FrequencyInterval = 10 where Identifier = 'test job 2';
select * from scheduler.task
exec scheduler.CreateJobFromTask @identifier = 'test job 2', @overwriteExisting = 1;
go
/* Add print step to produce output and allow testing execution framework (did the ExecuteTask proc execute?) */
update scheduler.task set TSQLCommand = 'print ''hi from job''' where Identifier = 'test job 2';
exec scheduler.CreateJobFromTask @identifier = 'test job 2', @overwriteExisting = 1;
/* Add a task which will fail */
INSERT INTO scheduler.Task
           (Identifier
           ,TSQLCommand
           ,StartTime
           ,FrequencyType
           ,FrequencyInterval
           ,NotifyOnFailureOperator)
     VALUES
    ('failjob'
    ,'select 1/0'
    ,'00:00'
    ,1
    ,0
    ,'Test Operator');
go
exec scheduler.CreateJobFromTask @identifier = 'failjob', @overwriteExisting = 1;
go
declare @id int = (select TaskId from scheduler.Task where identifier = 'failjob')
/* Should throw an error */
exec scheduler.ExecuteTask @taskId = @id;
go
/* This agent job should trigger failure notification 
	- Note if you don't have DB mail configure the notification won't get sent */
exec msdb.dbo.sp_start_job @job_name = 'failjob'
go
/* Check task execution history */
select *
from scheduler.TaskExecution