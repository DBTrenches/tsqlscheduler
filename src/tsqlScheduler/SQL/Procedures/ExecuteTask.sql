create or alter procedure scheduler.ExecuteTask
  @taskUid uniqueidentifier = null
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
  )
  begin
    ;throw 50000, 'Specified Task does not exist', 1;
  end

  declare @executionId int
      ,@startDateTime datetime2 (3) = getutcdate()
      ,@monthOfYear tinyint
      ,@command nvarchar(max)
      ,@isEnabled bit
      ,@isDeleted bit
      ,@isNotifyOnFailure bit
      ,@isSchedulerDatabaseWriteable bit;
  
  set  @monthOfYear = cast(month(@startDateTime) as tinyint)
  
  select  @command = t.TSQLCommand
      ,@isEnabled = t.IsEnabled
      ,@isDeleted = t.IsDeleted
      ,@isNotifyOnFailure = t.IsNotifyOnFailure
      ,@isSchedulerDatabaseWriteable = 
      case databasepropertyex(db_name(), 'Updateability')
        when 'READ_WRITE' then 1
        else 0
      end
  from  scheduler.Task as t
  where t.TaskUid = @taskUid;

  /* Run the task only:
    - If it is enabled
    - It isn't deleted
    - The scheduler database is writeable
      - Might be a read only replica
      - Or non-writeable for some other reason
  */
  if @isEnabled = 0 or @isDeleted = 1 or @isSchedulerDatabaseWriteable = 0
  begin
    return;
  end

  insert into scheduler.TaskExecution
  ( TaskUid, StartDateTime )
  values
  ( @taskUid, @startDateTime );

  select @executionId = scope_identity();

  declare @errorNumber int
      ,@resultMessage nvarchar(max)
      ,@isError bit = 0
      ,@id uniqueidentifier;

  select @id = i.Id
  from scheduler.GetInstanceId() as i;

  exec scheduler.SetContextInfo
    @instanceIdentifier = @id
    ,@taskUid = @taskUid
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
  where ExecutionId = @executionId and MonthOfYear = @monthOfYear;

  /* Throw here to allow agent to message the failure operator */
  if @isError = 1 and @isNotifyOnFailure = 1
  begin
    ;throw 50000, @resultMessage, 1;
  end
end
go
