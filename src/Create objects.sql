/* 010 - Create scheduler schema */
if schema_id('scheduler') is null
begin
	exec sp_executesql N'create schema scheduler authorization dbo;';
end
go

/* 020 - Create agent job creation proc */
create or alter procedure scheduler.CreateAgentJob
	@jobName nvarchar(128)
	,@command nvarchar(max)
	,@frequencyType varchar(6)
	,@frequencyInterval tinyint /* Ignored for day, every N for Hour/Minute */
	,@startTime time
	,@notifyOperator nvarchar(128)
	,@overwriteExisting bit = 0
as
begin
	set xact_abort on;
	set nocount on;

	declare @FREQUENCY_DAY varchar(6) = 'day'
		,@FREQUENCY_HOUR varchar(6) = 'hour'
		,@FREQUENCY_MINUTE varchar(6) = 'minute'
		,@ACTIVE_START_DATE int = 20160101;

	/* Validate parameters for basic correctness */
	if @jobName is null
	begin
		;throw 50000, '@jobName must be specified', 1;
	end

	if @command is null
	begin
		;throw 50000, '@command must be specified', 1;
	end

	if @frequencyType is null
	begin
		;throw 50000, '@frequencyType must be specified', 1;
	end

	if @frequencyInterval is null
	begin
		;throw 50000, '@frequencyInterval must be specified', 1;
	end

	if @startTime is null
	begin
		;throw 50000, '@startTime must be specified', 1;
	end

	if @notifyOperator is null
	begin
		;throw 50000, '@notifyOperator must be specified', 1;
	end

	/* Extended validation */
	if @frequencyType not in (@FREQUENCY_DAY, @FREQUENCY_HOUR, @FREQUENCY_MINUTE)
	begin
		;throw 50000, '@frequencyType must be one of: day, hour, minute',1;
	end

	if @frequencyType = @FREQUENCY_DAY and @frequencyInterval <> 0
	begin
		;throw 50000, 'Daily frequency only supports an interval of 0 (once per day)', 1;
	end

	if @frequencyType = @FREQUENCY_HOUR and @frequencyInterval > 23
	begin
		;throw 50000, 'Hourly frequency with an interval of 24 hours or more are not supported', 1;
	end

	if @frequencyType = @FREQUENCY_HOUR and not @frequencyInterval between 1 and 23
	begin
		;throw 50000, 'Hourly frequency requires an interval between 1 and 23', 1;
	end

	if @frequencyType = @FREQUENCY_MINUTE and not @frequencyInterval between 1 and 3599
	begin
		;throw 50000, 'Minute frequency requires an interval between 1 and 3599', 1;
	end

	/* Validate job does not already exist (if overwrite is not specified)
	   Validate operator exists 
	*/

	declare @existingJobId uniqueidentifier;

	select @existingJobId = s.job_id
	from msdb.dbo.sysjobs as s
	where s.name = @jobName;

	if @existingJobId is not null and @overwriteExisting = 0
	begin
		;throw 50000, 'Specified job name already exists', 1;
	end

	if not exists (
		select 1
		from msdb.dbo.sysoperators as o
		where o.name = @notifyOperator
	)
	begin
		;throw 50000, 'Specified @notifyOperator does not exist', 1;
	end
	

	/* Perform job management in a transaction (don't leave behind half-complete work)
		- Let xact_abort 'handle' our errors for now
	*/
	begin tran
		/* Delete existing job if we need to */
		if @existingJobId is not null and @overwriteExisting = 1
		begin
			exec msdb.dbo.sp_delete_job @job_id = @existingJobId;
		end
		
		/* MSDN docs for job creation: https://msdn.microsoft.com/en-gb/library/ms187320.aspx */

		/* Convert start time into msdb format */
		/* Create the job 
			- Set owner to SA
			- Disable logging of failure to the windows event log
			- Set failure notification on email
		*/

		EXEC  msdb.dbo.sp_add_job @job_name=@jobName, 
				@notify_level_eventlog=0, 
				@notify_level_email=2, 
				@owner_login_name=N'sa', 
				@notify_email_operator_name=@notifyOperator;


		/* Add a job server (specifies this job should execute on this server) */
		EXEC msdb.dbo.sp_add_jobserver @job_name=@jobName;

		/* Add the TSQL job step, homed in the master database */
		EXEC msdb.dbo.sp_add_jobstep 
				@job_name=@jobName
				,@step_name=@jobName
				,@subsystem=N'TSQL'
				,@command=@command
				,@database_name=N'master';
		

		/* Add a schedule with the same name as the job 
			sp_add_jobschedule: https://msdn.microsoft.com/en-gb/library/ms187320.aspx
			Frequency is always daily, how often per-day is based on parameters
		*/

		declare @freq_subday_type int
				,@active_start_time int;

		set @freq_subday_type = case @frequencyType
									when @FREQUENCY_DAY then 1
									when 'second' then 2 /* NYI: Seconds */
									when @FREQUENCY_HOUR then 8
									when @FREQUENCY_MINUTE then 4
								end;
		
		set @active_start_time = (datepart(hour,@startTime) * 10000) + (datepart(minute, @startTime) * 100) + datepart(second, @startTime);
		
		EXEC msdb.dbo.sp_add_jobschedule 
				@job_name=@jobName
				,@name=@jobName
				,@freq_type=4	/* Daily */
				,@freq_interval=1
				,@freq_subday_type=@freq_subday_type
				,@freq_subday_interval = @frequencyInterval
				,@active_start_date=@ACTIVE_START_DATE
				,@active_end_date=99991231
				,@active_start_time=@active_start_time
				,@active_end_time=235959;

	commit tran
end
go

/* 030 - Create table to store task details */
if exists (
	select 1
	from sys.tables as t
	where t.temporal_type <> 0 
	and t.name = 'task'
	and t.schema_id = schema_id('scheduler')
)
begin
	alter table scheduler.task set (system_versioning = off);
end
go
drop table if exists scheduler.Task;
drop table if exists scheduler.TaskHistory;
go
create table scheduler.Task
(
	TaskId int identity(1,1) not null
	,Identifier nvarchar(128) not null
	,TSQLCommand nvarchar(max) not null
	,StartTime time not null
	,FrequencyType tinyint not null
	,FrequencyTypeDesc as case FrequencyType when 1 then 'Day' when 2 then 'Hour' when 3 then 'Minute' when 4 then 'Second' end
	,FrequencyInterval smallint not null
	,NotifyOnFailureOperator nvarchar(128) not null
	,SysStartTime datetime2 generated always as row start not null
	,SysEndTime datetime2 generated always as row end not null
	,period for system_time (SysStartTime, SysEndTime)
	,constraint PK_Task primary key clustered (TaskId) with (data_compression = page)
	,constraint UQ_Task_Name unique nonclustered (Identifier) with (data_compression = page)
) with (system_versioning = on (history_table = scheduler.TaskHistory))
go

/* 040 - Create a job to turn a task into a job */
create or alter procedure scheduler.CreateJobFromTask
	@taskId int = null
	,@identifier nvarchar(128) = null
	,@overwriteExisting bit = 0
as
begin
	set xact_abort on;
	set nocount on;

	if @taskId is null and @Identifier is null
	begin
		;throw 50000, 'One of @taskId or @identifier must be specified', 1;
	end

	if @overwriteExisting is null
	begin
		;throw 50000, '@overwriteExisting cannot be null', 1;
	end

	if @taskId is null
	begin
		select @taskId = t.TaskId
		from scheduler.Task as t
		where t.Identifier = @identifier;
	end

	if not exists (
		select 1
		from scheduler.Task as t
		where t.TaskId = @taskId
	)
	begin
		;throw 50000, 'Specified Task does not exist', 1;
	end

	
	
	declare @jobName nvarchar(128)
			,@command nvarchar(max)
			,@frequencyType varchar(5)
			,@frequencyInterval tinyint
			,@startTime time
			,@notifyOperator nvarchar(128);

	select	@jobName = t.Identifier
			,@command = t.TSQLCommand
			,@frequencyType = t.FrequencyTypeDesc
			,@frequencyInterval = t.FrequencyInterval
			,@startTime = t.StartTime
			,@notifyOperator = t.NotifyOnFailureOperator
	from	scheduler.Task as t
	where	t.TaskId = @taskId;

	exec scheduler.CreateAgentJob
			@jobName = @jobName
			,@command = @command
			,@frequencyType = @frequencyType
			,@frequencyInterval = @frequencyInterval
			,@startTime = @startTime
			,@notifyOperator = @notifyOperator
			,@overwriteExisting = @overwriteExisting;
end
go