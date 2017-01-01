/* Create scheduler schema */
if schema_id('scheduler') is null
begin
	exec sp_executesql N'create schema scheduler authorization dbo;';
end
go

/* Create agent job creation proc */
create or alter procedure scheduler.CreateAgentJob
	@jobName nvarchar(128)
	,@command nvarchar(max)
	,@frequencyType varchar(6)
	,@frequencyInterval tinyint /* Ignored for day, every N for Hour/Minute */
	,@startTime time
	,@notifyOperator nvarchar(128)
	,@overwriteExisting bit = 0
	,@description nvarchar(max) = null
as
begin
	set xact_abort on;
	set nocount on;

	declare @FREQUENCY_DAY varchar(6) = 'day'
		,@FREQUENCY_HOUR varchar(6) = 'hour'
		,@FREQUENCY_MINUTE varchar(6) = 'minute'
		,@FREQUENCY_SECOND varchar(6) = 'second'
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
	if @frequencyType not in (@FREQUENCY_DAY, @FREQUENCY_HOUR, @FREQUENCY_MINUTE, @FREQUENCY_SECOND)
	begin
		;throw 50000, '@frequencyType must be one of: day, hour, minute, second',1;
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
		;throw 50000, 'Minute frequency requires an interval between 1 and 3599 (1 minute to 1 day)', 1;
	end

	if @frequencyType = @FREQUENCY_SECOND and not @frequencyInterval between 1 and 3599
	begin
		;throw 50000, 'Second frequency requires an interval between 1 and 3599 (1 second to 1 hour)', 1;
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
			- Add audit information to description
		*/

		declare @currentUser nvarchar(128) = suser_name()
				,@currentHost nvarchar(128) = host_name()
				,@currentApplication nvarchar(128) = app_name()
				,@currentDate nvarchar(128) = convert(nvarchar(128),getutcdate(), 20)
				,@crlf char(2) = char(13) + char(10);

		declare @jobDescription nvarchar(max) = formatmessage('Created with CreateAgentJob%sUser:%s%sHost:%s%sApplication:%s%sTime:%s', @crlf, @currentUser, @crlf, @currentHost, @crlf, @currentApplication, @crlf, @currentDate);
		if @description is not null
		begin
			set @jobDescription = @jobDescription + @crlf + 'Info:' + @description
		end

		EXEC  msdb.dbo.sp_add_job 
				@job_name=@jobName
				,@notify_level_eventlog=0
				,@notify_level_email=2
				,@owner_login_name=N'sa'
				,@notify_email_operator_name=@notifyOperator
				,@description = @jobDescription;

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
									when @FREQUENCY_SECOND then 2
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

/* Create table to store task details */
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
	,IsNotifyOnFailure bit not null constraint DF_Task_IsNotifyOnFailure default (1)
	,IsEnabled bit not null constraint DF_Task_IsEnabled default (1)
	,AvailabilityGroup nvarchar(128) null
	,IsJobUpsertRequired bit not null constraint DF_Task_IsJobUpserRequired default (1)
	,SysStartTime datetime2 generated always as row start not null
	,SysEndTime datetime2 generated always as row end not null
	,period for system_time (SysStartTime, SysEndTime)
	,constraint PK_Task primary key clustered (TaskId) with (data_compression = page)
	,constraint UQ_Task_Name unique nonclustered (Identifier) with (data_compression = page)
) with (system_versioning = on (history_table = scheduler.TaskHistory))
go

/* Create a proc to turn a task into a job */
create or alter procedure scheduler.CreateJobFromTask
	@taskId int = null
	,@identifier nvarchar(128) = null
	,@overwriteExisting bit = 0
as
begin
	set xact_abort on;
	set nocount on;

	if (@taskId is null and @identifier is null) or (@taskId is not null and @identifier is not null)
	begin
		;throw 50000, 'Only one of @taskId or @identifier must be specified', 1;
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
			,@frequencyType varchar(6)
			,@frequencyInterval tinyint
			,@startTime time
			,@notifyOperator nvarchar(128)
			,@description nvarchar(max);

	declare @db nvarchar(max) = db_name(db_id());

	set @description = 'Created from task ' + cast(@taskId as varchar(12)) + ' in database ' + @db;
	
	select	@jobName = t.Identifier
			,@frequencyType = t.FrequencyTypeDesc
			,@frequencyInterval = t.FrequencyInterval
			,@startTime = t.StartTime
			,@notifyOperator = t.NotifyOnFailureOperator
	from	scheduler.Task as t
	where	t.TaskId = @taskId;
	
	set @command = 'exec ' + @db + '.scheduler.ExecuteTask @taskId = ' + cast(@taskId as varchar(12)) + ';';

	exec scheduler.CreateAgentJob
			@jobName = @jobName
			,@command = @command
			,@frequencyType = @frequencyType
			,@frequencyInterval = @frequencyInterval
			,@startTime = @startTime
			,@notifyOperator = @notifyOperator
			,@overwriteExisting = @overwriteExisting
			,@description = @description;
end
go

/* Add procedure to test for AG replica status 
	- Use a procedure rather than directly querying the system views to enable testing without creating/requiring AGs */
create or alter function scheduler.GetAvailabilityGroupRole
(
	@availabilityGroupName nvarchar(128)
)
returns nvarchar(60)
as
begin
	declare @role nvarchar(60);

	if @availabilityGroupName = N'ALWAYS_PRIMARY'
	begin
		return N'PRIMARY';
	end
	else if @availabilityGroupName = N'NEVER_PRIMARY'
	begin
		return N'SECONDARY';
	end

	select		@role = ars.role_desc
	from		sys.dm_hadr_availability_replica_states ars
	inner join	sys.availability_groups ag
	on			ars.group_id = ag.group_id
	where		ag.name = @availabilityGroupName
	and			ars.is_local = 1;

	return coalesce(@role,'');
end
go

/* Add execution logging table */
drop table if exists scheduler.TaskExecution;
go
create table scheduler.TaskExecution
(
	ExecutionId int identity(1,1) not null
	,TaskId int not null
	,StartDateTime datetime2(3) not null constraint DF_TaskExecution_StartDateTime default getutcdate()
	,EndDateTime datetime2(3) null
	,IsError bit not null constraint DF_TaskExecution_IsError default (0)
	,ResultMessage nvarchar(max) null
	,constraint PK_TaskExecution primary key clustered (ExecutionId) with (data_compression = page)
);
go

/* Add a proc to execute a task */
create or alter procedure scheduler.ExecuteTask
	@taskId int = null
	,@identifier nvarchar(128) = null
as
begin
	set xact_abort on;
	set nocount on;

	if (@taskId is null and @identifier is null) or (@taskId is not null and @identifier is not null)
	begin
		;throw 50000, 'Only one of @taskId or @identifier must be specified', 1;
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

	declare @executionId int
			,@command nvarchar(max)
			,@isEnabled bit
			,@isNotifyOnFailure bit
			,@availabilityGroupName nvarchar(128);

	select	@command = t.TSQLCommand
			,@isEnabled = t.IsEnabled
			,@isNotifyOnFailure = t.IsNotifyOnFailure
			,@availabilityGroupName = t.AvailabilityGroup
	from	scheduler.Task as t
	where	t.TaskId = @taskId;

	/* Run the task only if it is enabled and we're on the right replica (or no AG specified) */
	if @isEnabled = 0
	begin
		return;
	end

	if @availabilityGroupName is not null and scheduler.GetAvailabilityGroupRole(@availabilityGroupName) <> N'PRIMARY'
	begin
		return;
	end

	insert into scheduler.TaskExecution
	( TaskId )
	values
	( @taskId )

	select @executionId = scope_identity();

	declare @errorNumber int
			,@resultMessage nvarchar(max)
			,@isError bit = 0;

	begin try
		exec sp_executesql @command;
	end try
	begin catch
		set @isError = 1;
		set @errorNumber = error_number();
		set @resultMessage = cast(@errorNumber as varchar(10)) + ' - ' + error_message();
	end catch

	update scheduler.TaskExecution
		set IsError = @isError
			,ResultMessage = @resultMessage
			,EndDateTime = getutcdate()
	where ExecutionId = @executionId;

	/* Throw here to allow agent to message the failure operator */
	if @isError = 1 and @isNotifyOnFailure = 1
	begin
		;throw 50000, @resultMessage, 1;
	end
end
go

/* Procedure to create jobs from all tasks present in the Task table */
create or alter procedure scheduler.CreateJobsForAllTasks
as
begin
	set xact_abort on;
	set nocount on;

	declare @id int
			,@maxId int
			,@taskId int;

	drop table if exists #work;

	select	identity(int,1,1) as Id
			,cast(t.TaskId as int) as TaskId
	into #work
	from scheduler.Task as t
	where t.IsJobUpsertRequired = 1;

	set @maxId = SCOPE_IDENTITY();
	set @id = 1;

	while @id <= @maxId
	begin
		select @taskId = w.TaskId
		from #work as w
		where w.Id = @id;
		
		begin try
			exec scheduler.CreateJobFromTask @taskId = @taskId, @overwriteExisting = 1;
			
			update scheduler.Task
				set IsJobUpsertRequired = 0
			where TaskId = @taskId;
		end try
		begin catch
			/* Swallow error - we don't want to take out the whole run if a single task fails to create */
		end catch
		set @id += 1;
	end
end
go