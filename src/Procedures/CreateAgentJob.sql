create or alter procedure scheduler.CreateAgentJob
	@jobName nvarchar(128)
	,@stepName sysname
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

		exec  msdb.dbo.sp_add_job 
				@job_name = @jobName
				,@notify_level_eventlog = 0
				,@notify_level_email = 2
				,@owner_login_name = N'sa'
				,@notify_email_operator_name = @notifyOperator
				,@description = @jobDescription;

		/* Add a job server (specifies this job should execute on this server) */
		EXEC msdb.dbo.sp_add_jobserver @job_name=@jobName;

		/* Add the TSQL job step, homed in the master database */
		EXEC msdb.dbo.sp_add_jobstep 
				@job_name = @jobName
				,@step_name= @stepName
				,@subsystem = N'TSQL'
				,@command = @command
				,@database_name = N'master';

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
		
		/* Convert start time into msdb format */
		set @active_start_time = (datepart(hour,@startTime) * 10000) + (datepart(minute, @startTime) * 100) + datepart(second, @startTime);
		
		exec msdb.dbo.sp_add_jobschedule 
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