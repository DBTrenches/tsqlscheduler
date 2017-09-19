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
			,@availabilityGroupName nvarchar(128)
			,@isCachedRoleCheck bit;

	select	@command = t.TSQLCommand
			,@isEnabled = t.IsEnabled
			,@isNotifyOnFailure = t.IsNotifyOnFailure
			,@availabilityGroupName = t.AvailabilityGroup
			,@identifier = t.Identifier
			,@isCachedRoleCheck = t.IsCachedRoleCheck

	from	scheduler.Task as t
	where	t.TaskId = @taskId;

	/* Run the task only if it is enabled and we're on the right replica (or no AG specified) */
	if @isEnabled = 0
	begin
		return;
	end

  	if @availabilityGroupName is not null
	begin
		/* Are we requesting a non-cached result? */
		if @isCachedRoleCheck = 0 and scheduler.GetAvailabilityGroupRole(@availabilityGroupName) <> N'PRIMARY'
		begin
			return;
		end
		else if scheduler.GetCachedAvailabilityGroupRole(@availabilityGroupName) <> N'PRIMARY'
		begin
  			return;
		end
	end

	insert into scheduler.TaskExecution
	( TaskId )
	values
	( @taskId );

	select @executionId = scope_identity();

	declare @errorNumber int
			,@resultMessage nvarchar(max)
			,@isError bit = 0
			,@id uniqueidentifier;

	select @id = i.Id
	from scheduler.GetInstanceId() as i;

	exec scheduler.SetContextInfo
		@instanceIdentifier = @id
		,@taskId = @taskId
		,@executionId = @executionId;

	begin try
		exec sp_executesql @command;
	end try
	begin catch
		set @isError = 1;
		set @errorNumber = error_number();
		set @resultMessage = cast(@errorNumber as varchar(10)) + ' - ' + error_message();

		if xact_state() in (-1,1)
		begin
			rollback transaction;
		end
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