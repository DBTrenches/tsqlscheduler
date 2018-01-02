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
		,@ACTIVE_START_DATE int = datepart(year,getutcdate()) * 10000 + datepart(month,getutcdate()) * 100 + datepart(day,getutcdate());

    declare 
        @frequencyTypeNum tinyint = scheduler.FrequencyTypeFromDesc( @frequencyType ),
        @IsValidTask bit = 1,
        @Comments nvarchar(max),
        @ErrorMsg nvarchar(max) = N'',
        @existingJobId uniqueidentifier;
	
    select
        @IsValidTask = tv.IsValidTask,
        @Comments = tv.Comments,
        @existingJobId = tv.ExistingJobID
    from scheduler.ValidateTaskProfile (
        null,
        @jobName,
        @command,
        @startTime,
        @frequencyTypeNum,
        @frequencyInterval,
        @notifyOperator,
        1,
        @overwriteExisting
    ) tv;

    if @IsValidTask = 0
    begin
        with errors (msg) as (
            select msg
            from openjson(@Comments) 
            with (msg nvarchar(max) 'strict $.msg') 
        )
        select @ErrorMsg += msg+char(10)
        from errors;

        throw 50000, @ErrorMsg, 1;
    end;

	/* Delete existing job if we need to */
	if @existingJobId is not null and @overwriteExisting = 1
	begin
		exec msdb.dbo.sp_delete_job @job_id = @existingJobId;
	end

	/* Perform job management in a transaction (don't leave behind half-complete work)
		- Let xact_abort 'handle' our errors for now
	*/
	begin tran
		
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

	/* Add a job server (specifies this job should execute on this server) 
		- This also sends SQLAgent a notification to refresh its cache
		- Do this outside of the transaction to ensure SQL Agent will see the changes
	*/
	EXEC msdb.dbo.sp_add_jobserver @job_name=@jobName;
end
go