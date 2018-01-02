
create or alter proc scheduler.DeleteTask
    @task sysname
as
begin;
	set nocount on;
    set xact_abort on;

    declare 
        @taskId int,
        @ErrorMsg nvarchar(max);

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

    update scheduler.Task set
        IsDeleted = 1
    where TaskId = @taskId;

    if @@rowcount = 0
    begin;
        set @ErrorMsg = formatmessage('No tasks deleted for specified task [%s]',@task);
        throw 50000, @ErrorMsg, 1;
    end;
end;
go
