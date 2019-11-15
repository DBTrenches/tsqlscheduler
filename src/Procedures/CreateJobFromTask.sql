create or alter procedure scheduler.CreateJobFromTask
  @taskUid uniqueidentifier = null
  ,@overwriteExisting bit = 0
as
begin
  set xact_abort on;
  set nocount on;

  if (@taskUid is null)
  begin
    ;throw 50000, '@taskUid must be specified', 1;
  end

  if @overwriteExisting is null
  begin
    ;throw 50000, '@overwriteExisting cannot be null', 1;
  end

  if not exists (
    select 1
    from scheduler.Task as t
    where t.TaskUid = @taskUid
  )
  begin
    ;throw 50000, 'Specified Task does not exist', 1;
  end

  declare @jobName nvarchar(128)
      ,@command nvarchar(max)
      ,@frequency varchar(6)
      ,@frequencyInterval tinyint
      ,@startTime time
      ,@notifyOperator nvarchar(128)
      ,@description nvarchar(max)
      ,@notifyLevelEventlog varchar(9) 
      ,@db nvarchar(max) = db_name();

  select  @jobName = concat_ws('-',@db,t.Identifier)
      ,@frequency = t.Frequency
      ,@frequencyInterval = t.FrequencyInterval
      ,@startTime = t.StartTime
      ,@notifyOperator = t.NotifyOnFailureOperator
      ,@notifyLevelEventlog=t.NotifyLevelEventlog
      ,@taskUid = t.TaskUid
  from  scheduler.Task as t
  where	t.taskUid = @taskUid;

  set @description = (select @db as db
    ,id.Id as instanceId
    ,@taskUid as taskUid
    ,getutcdate() as updateCreateDate
  from  scheduler.GetInstanceId() as id
  for json path, without_array_wrapper)
  
  set @command = 'exec ' + @db + '.scheduler.ExecuteTask @taskUid = ' + cast(@taskUid as varchar(36)) + ';';

  exec scheduler.CreateAgentJob
      @taskUid = @taskUid
      ,@jobName = @jobName
      ,@stepName = @jobName
      ,@command = @command
      ,@frequency = @frequency
      ,@frequencyInterval = @frequencyInterval
      ,@startTime = @startTime
      ,@notifyOperator = @notifyOperator
      ,@notifyLevelEventlog=@notifyLevelEventlog
      ,@overwriteExisting = @overwriteExisting
      ,@description = @description;
end