
create or alter proc scheduler.GetTask
     @task sysname
    ,@asof datetime2 = null
as
/*
Get the definition of a given task for use in "UpsertTask" sub-modules

exec scheduler.GetTask 1;
*/
begin;
    set nocount on;
    set xact_abort on;
    
    declare 
        @msg nvarchar(max),
        @taskId int;
    
    if isnumeric(@task)=0
    begin;
        select @taskId = TaskId
        from scheduler.Task 
        where Identifier = @task;
    end
    else 
    begin;
        select @taskId = TaskId 
        from scheduler.Task 
        where TaskId = try_cast(@task as int);    
    end;


    if @taskId is null
    begin;
        set @msg = formatmessage('Selected task [%s] is not valid. Please provide a valid task Name OR task ID.',@task);
        throw 50000, @msg, 1;
    end;

    if @asof is null set @asof=getutcdate();

    select @msg=
           '     @taskId = '               +convert(nvarchar(max),TaskId)
+nchar(10)+'    ,@jobIdentifier = N'''     +convert(nvarchar(max),Identifier)             +''''
+nchar(10)+'    ,@tsqlCommand = N'''       +convert(nvarchar(max),TSQLCommand)            +''''
+nchar(10)+'    ,@startTime = N'''         +convert(nvarchar(max),StartTime)              +''''
+nchar(10)+'    ,@frequencyType = '        +convert(nvarchar(max),FrequencyType)
+nchar(10)+'    ,@frequencyTypeDesc = N''' +convert(nvarchar(max),FrequencyTypeDesc)      +''''
+nchar(10)+'    ,@frequencyInterval = '    +convert(nvarchar(max),FrequencyInterval)
+nchar(10)+'    ,@notifyOperator = N'''    +convert(nvarchar(max),NotifyOnFailureOperator)+''''
+nchar(10)+'    ,@isNotifyOnFailure = '    +convert(nvarchar(max),IsNotifyOnFailure)
+nchar(10)+'    ,@isEnabled = '            +convert(nvarchar(max),IsEnabled)
--+nchar(10)+'    ,@isCachedRoleCheck = '    +convert(nvarchar(max),IsCachedRoleCheck)
+nchar(10)+'    ,@isDeleted = '            +convert(nvarchar(max),IsDeleted)
    from (
        select TaskId,
               Identifier,
               TSQLCommand,
               StartTime,
               FrequencyType,
               FrequencyTypeDesc,
               FrequencyInterval,
               NotifyOnFailureOperator,
               IsNotifyOnFailure,
               IsEnabled,
--               IsCachedRoleCheck,
               IsDeleted
        from scheduler.Task 
        for system_time as of @asof
        where TaskId = @taskId
    ) x;

    if @msg is null
    begin;
        set @msg = formatmessage('Selected task [%s] did not exist at select datetime [%s].',@task,convert(varchar(27),@asof));
    end;
    
    print @msg;

    return;
end;
go
