create or alter procedure scheduler.RemoveJobFromTask
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
		and t.Isdeleted=1
	)
	begin
		;throw 50000, 'Specified task does not exists or it has not been marked for deletion ', 1;
	end

	declare @jobName nvarchar(128)
			
	select	@jobName = t.Identifier
	from	scheduler.Task as t
	where	t.TaskId = @taskId;
	
	exec scheduler.DeleteAgentJob
			@jobName = @jobName;
			
end