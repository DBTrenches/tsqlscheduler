
create or alter proc scheduler.EnableTask
    @task sysname
as
begin;
    set nocount on;
    set xact_abort on;
    
    declare 
        @msg nvarchar(max),
        @taskId int,
        @taskName sysname,
        @isEnabled bit;

    select @taskId = TaskID
          ,@taskName = Identifier
    from scheduler.GetTaskID(@task,0);

    if @taskId is null
    begin;
        set @msg = formatmessage('Selected task [%s] is not valid. Please provide a valid task Name OR task ID.',@task);
        throw 50000, @msg, 1;
        return;
    end;
    
    select @isEnabled = IsEnabled
    from scheduler.Task
    where TaskId = @taskId;

    if @isEnabled = 1
    begin;
        set @msg = formatmessage('Task [%s] ID [%i] is already ENABLED.',@taskName,@taskId);
        throw 50000, @msg, 1;
        return;
    end;

    update scheduler.Task set 
        IsEnabled = 1
    where TaskId = @taskId;

    set @msg = formatmessage('Successfully ENABLED task [%s], ID [%i].',@taskName,@taskId);
    print @msg;

    return;
        
end;
go
