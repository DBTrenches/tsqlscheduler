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
			,@description nvarchar(max)
			,@notifyLevelEventlog int 
	declare @db nvarchar(max) = db_name(db_id());

	set @description = 'Created from task ' + cast(@taskId as varchar(12)) + ' in database ' + @db;
	
	select	@jobName = t.Identifier
			,@frequencyType = t.FrequencyTypeDesc
			,@frequencyInterval = t.FrequencyInterval
			,@startTime = t.StartTime
			,@notifyOperator = t.NotifyOnFailureOperator
			,@notifyLevelEventlog=t.NotifyLevelEventlog
	from	scheduler.Task as t
	where	t.TaskId = @taskId;
	
	set @command = 'exec ' + @db + '.scheduler.ExecuteTask @taskId = ' + cast(@taskId as varchar(12)) + ';';

	exec scheduler.CreateAgentJob
			@jobName = @jobName
			,@stepName = @jobName
			,@command = @command
			,@frequencyType = @frequencyType
			,@frequencyInterval = @frequencyInterval
			,@startTime = @startTime
			,@notifyOperator = @notifyOperator
			,@notifyLevelEventlog=@notifyLevelEventlog
			,@overwriteExisting = @overwriteExisting
			,@description = @description;
end