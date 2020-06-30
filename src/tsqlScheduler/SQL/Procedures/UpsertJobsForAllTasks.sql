create or alter procedure scheduler.UpsertJobsForAllTasks
as
begin
  set xact_abort on;
  set nocount on;

  declare @id int
      ,@maxId int
      ,@taskUid uniqueidentifier;

  /*Update Existing and Create New Jobs*/
  drop table if exists #UpdateCreateWork;
  create table #UpdateCreateWork
  (
    Id  int not null identity(1, 1) primary key,
    TaskUid uniqueidentifier not null
  );

  insert into #UpdateCreateWork
          (TaskUid)
  select  t.TaskUid 
  from    scheduler.Task as t
  where   t.IsDeleted = 0
  and not exists (
    select 1
    from 	msdb.dbo.sysjobs j 
    cross apply openjson (j.Description, N'$')
    with (
        InstanceId      uniqueidentifier    N'$.instanceId'
        ,TaskUid        uniqueidentifier    N'$.taskUid'
    ) as task
    cross apply scheduler.GetInstanceId() as id
    where	isjson(j.description) = 1
    and   id.Id = task.InstanceId
    and   t.TaskUid = task.TaskUid
    and   j.date_modified >= t.sysStartTime
  );

  set @maxId = scope_identity();
  set @id = 1;

  while @id <= @maxId
  begin
    select @taskUid = w.TaskUid
    from #UpdateCreateWork as w
    where w.Id = @id;
    
    begin try
      exec scheduler.CreateJobFromTask @taskUid = @taskUid, @overwriteExisting = 1;
    end try
    begin catch
      if xact_state() in (-1,1)
      begin
        rollback tran;
      end
	  print error_message()
	  print @taskUid
      /* Swallow error - we don't want to take out the whole run if a single task fails to create */
    end catch
    set @id += 1;
  end

    /* Delete existing jobs marked for deletion */
  drop table if exists #DeleteWork;
  create table #DeleteWork
  (
    Id  int not null identity(1, 1) primary key,
    TaskUid uniqueidentifier not null
  );

  insert into #DeleteWork
          (TaskUid)
  select  t.TaskUid 
  from    scheduler.Task as t
  where   t.IsDeleted = 1
  and exists  (
    select 1
    from 	msdb.dbo.sysjobs j 
    cross apply openjson (j.Description, N'$')
    with (
        InstanceId      uniqueidentifier    N'$.instanceId'
        ,TaskUid        uniqueidentifier    N'$.taskUid'
    ) as task
    cross apply scheduler.GetInstanceId() as id
    where	isjson(j.description) = 1
    and   id.Id = task.InstanceId
    and   t.TaskUid = task.TaskUid
  );

  set @maxId = (select max(dw.Id) from #DeleteWork dw);
  set @id = 1;

  while @id <= @maxId
  begin
    select @taskUid = w.TaskUid
    from #DeleteWork as w
    where w.Id = @id;
    
    begin try
      exec scheduler.RemoveJobFromTask @taskUid = @taskUid;
    end try
    begin catch
      if xact_state() in (-1,1)
      begin
        rollback tran;
      end
	  print error_message()
	  print @taskUid
      /* Swallow error - we don't want to take out the whole run if a single task fails to create */
    end catch
    set @id += 1;
  END
end
