
create or alter function scheduler.GetTaskID (
     @task sysname
    ,@fuzzyMatch bit
)
returns table 
as 
return (
    select TaskID, Identifier
    from scheduler.Task
    where TaskID = try_cast(@task as int) 
        or @task = Identifier
    union all 
    select TaskID, Identifier
    from scheduler.Task
    where Identifier like '%'+@task+'%'
        and @fuzzyMatch = 1
);
go
