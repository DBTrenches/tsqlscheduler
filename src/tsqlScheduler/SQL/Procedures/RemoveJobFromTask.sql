create or alter procedure scheduler.RemoveJobFromTask
  @taskUid uniqueidentifier = null
  ,@identifier nvarchar(128) = null
as
begin
  set xact_abort on;
  set nocount on;

  if (@taskUid is null)
  begin
    ;throw 50000, '@taskUid must be specified', 1;
  end

  if not exists (
    select 1
    from scheduler.Task as t
    where t.TaskUid = @taskUid
    and t.IsDeleted = 1
  )
  begin
    ;throw 50000, 'Specified task does not exists or it has not been marked for deletion', 1;
  end

  exec scheduler.DeleteAgentJob @taskUid = @taskUid
end