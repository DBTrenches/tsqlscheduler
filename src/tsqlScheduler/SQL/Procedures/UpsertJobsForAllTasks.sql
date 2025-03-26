create procedure scheduler.UpsertJobsForAllTasks
as
begin
    set xact_abort on;
    set nocount on;

    declare @id      int
           ,@maxId   int
           ,@taskUid uniqueidentifier
           ,@dbcount int
           ,@db_name sysname          = N''
           ,@command as nvarchar(max) = N'';

    /*Update Existing and Create New Jobs*/
    drop table if exists #UpdateCreateWork;
    create table #UpdateCreateWork (
        Id      int              not null identity(1, 1) primary key
       ,TaskUid uniqueidentifier not null
    );

    create table #dbs (
        Id     int     not null identity(1, 1) primary key
       ,dbname sysname not null
    );

    insert into #dbs
    select  'DBAdmin'
    union all
    select      dbs.name
    from        sys.databases dbs
    inner join  sys.dm_hadr_database_replica_states drs
    on          dbs.database_id = drs.database_id
    inner join  sys.dm_hadr_availability_replica_states ars
    on          ars.replica_id = drs.replica_id
    inner join  sys.availability_replicas ar
    on          ar.replica_id = ars.replica_id
    where       ar.replica_server_name = @@SERVERNAME
    and         dbs.name like 'DBAdmin%'
    and
                (
                    drs.is_primary_replica = 1
              or    ar.secondary_role_allow_connections_desc = 'ALL'
                );

    set @dbcount = @@ROWCOUNT;
    set @id = 1;

    while @id <= @dbcount
    begin

        select  @db_name = dbname
        from    #dbs
        where   Id = @id;

        set @command = N'use ' + quotename (@db_name)  + N';

        declare @id      int = 1
               ,@maxId   int = 0
               ,@taskUid uniqueidentifier;

        truncate table #UpdateCreateWork;

        insert into #UpdateCreateWork (
        TaskUid
        )
        select  t.TaskUid
        from    scheduler.Task as t
        where   t.IsDeleted = 0
        and     not exists
        (
            select      1
            from        msdb.dbo.sysjobs j
            cross apply
                        openjson (j.Description, N''$'')
                        with
                        (
                            InstanceId uniqueidentifier N''$.instanceId''
                           ,TaskUid uniqueidentifier N''$.taskUid''
                        ) as task
            cross apply scheduler.GetInstanceId () as id
            where       isjson (j.description) = 1
            and         id.Id = task.InstanceId
            and         t.TaskUid = task.TaskUid
            and         j.date_modified >= t.sysStartTime
        );

        set @maxId =
        (
            select  max (Id) from #UpdateCreateWork
        );

        while @id <= @maxId
        begin
            select  @taskUid = w.TaskUid
            from    #UpdateCreateWork as w
            where   w.Id = @id;

            begin try
                exec scheduler.CreateJobFromTask @taskUid = @taskUid
                                                ,@overwriteExisting = 1;
            end try
            begin catch
                if xact_state () in ( -1, 1 )
                begin
                    rollback tran;
                end;
                print error_message ();
                print @taskUid;
            /* Swallow error - we don''t want to take out the whole run if a single task fails to create */
            end catch;
            set @id += 1;
        end;';

        exec sys.sp_executesql @command;
        set @id += 1;
    end;



    /* Delete existing jobs marked for deletion */
    drop table if exists #DeleteWork;
    create table #DeleteWork (
        Id      int              not null identity(1, 1) primary key
       ,TaskUid uniqueidentifier not null
    );

    set @id = 1;

    while @id <= @dbcount
    begin

        select  @db_name = dbname
        from    #dbs
        where   Id = @id;

        set @command = N'use ' + quotename (@db_name) + N';

        declare @id      int = 1
               ,@maxId   int = 0
               ,@taskUid uniqueidentifier;

        truncate table #DeleteWork;

        insert into #DeleteWork (
        TaskUid
        )
        select  t.TaskUid
        from    scheduler.Task as t
        where   t.IsDeleted = 1
        and     exists
        (
            select      1
            from        msdb.dbo.sysjobs j
            cross apply
                        openjson (j.description, N''$'')
                        with
                        (
                            InstanceId uniqueidentifier N''$.instanceId''
                           ,TaskUid uniqueidentifier N''$.taskUid''
                        ) as task
            cross apply scheduler.GetInstanceId () as id
            where       isjson (j.description) = 1
            and         id.Id = task.InstanceId
            and         t.TaskUid = task.TaskUid
        );

        set @maxId =
        (
            select  max (dw.Id) from #DeleteWork dw
        );

        while @id <= @maxId
        begin
            select  @taskUid = w.TaskUid
            from    #DeleteWork as w
            where   w.Id = @id;

            begin try
                exec scheduler.RemoveJobFromTask @taskUid = @taskUid;
            end try
            begin catch
                if xact_state () in ( -1, 1 )
           begin
                    rollback tran;
                end;
                print error_message ();
                print @taskUid;
            /* Swallow error - we don''t want to take out the whole run if a single task fails to create */
            end catch;
            set @id += 1;
        end;';

        exec sys.sp_executesql @command;
        set @id += 1;
    end;
       
    -- delete AG specific jobs (to be deleted after a failover) 
    -- cannot delete using "exec scheduler.RemoveJobFromTask" since AG is no longer accessible
    truncate table #DeleteWork;

    insert into #DeleteWork (
    TaskUid
    )
    select  j.job_id
    from    msdb.dbo.sysjobs j
    cross apply
            openjson (j.description, N'$')
            with
            (
                Db sysname N'$.db'
            ) as task
    where   isjson (j.description) = 1
    and     task.Db like 'DBAdminA%'
    and     task.Db not in
            (
                select dbname from #dbs
            );

    set @maxId = @@ROWCOUNT;
    set @id = 1;

    while @id <= @maxId
    begin
        select  @taskUid = w.TaskUid
        from    #DeleteWork as w
        where   w.Id = @id;

        begin try
            exec msdb.dbo.sp_delete_job @job_id = @taskUid
                                       ,@delete_unused_schedule = 1;
        end try
        begin catch
            if xact_state () in ( -1, 1 )
            begin
                rollback tran;
            end;
            print error_message ();
            print @taskUid;
        /* Swallow error - we don't want to take out the whole run if a single task fails to create */
        end catch;
        set @id += 1;
    end;

end;
GO
