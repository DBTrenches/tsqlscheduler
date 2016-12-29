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