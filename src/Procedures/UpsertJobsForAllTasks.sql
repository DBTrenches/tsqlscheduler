create or alter procedure scheduler.UpsertJobsForAllTasks
as
begin
	set xact_abort on;
	set nocount on;

	declare @id int
			,@maxId int
			,@taskId int
			,@autoCreateJobIdentifier nvarchar(128);

	set @autoCreateJobIdentifier = db_name() + N'-UpsertJobsForAllTasks';

	/*Update Existing and Create New Jobs*/
	drop table if exists #UpdateCreateWork;
	create table #UpdateCreateWork
	(
		Id	int not null identity(1, 1) primary key,
		TaskId int not null
	);

	insert into		#UpdateCreateWork
					(TaskId)
	select			t.TaskId 
	from			scheduler.Task as t
	where			t.Identifier <> @autoCreateJobIdentifier
	and				t.IsDeleted = 0
	and not exists (
		select	1 
		from 	msdb.dbo.sysjobs j 
		where 	j.name = t.Identifier 
		and		j.date_modified >= t.sysStartTime
	);

	set @maxId = scope_identity();
	set @id = 1;

	while @id <= @maxId
	begin
		select @taskId = w.TaskId
		from #UpdateCreateWork as w
		where w.Id = @id;
		
		begin try
			exec scheduler.CreateJobFromTask @taskId = @taskId, @overwriteExisting = 1;
		end try
		begin catch
			/* Swallow error - we don't want to take out the whole run if a single task fails to create */
		end catch
		set @id += 1;
	end

    /* Delete existing jobs marked for deletion */
	drop table if exists #DeleteWork;
	create table #DeleteWork
	(
		Id	int not null identity(1, 1) primary key,
		TaskId int not null
	);

	insert into		#DeleteWork
					(TaskId)
	select			t.TaskId 
	from			scheduler.Task as t
	where			t.Identifier <> @autoCreateJobIdentifier
	and				t.IsDeleted = 1
	and exists		(
		select	1 
		from	msdb.dbo.sysjobs j 
		where	j.name = t.Identifier 
	);

	set @maxId = scope_identity();
	set @id = 1;

	while @id <= @maxId
	begin
		select @taskId = w.TaskId
		from #DeleteWork as w
		where w.Id = @id;
		
		begin try
			exec scheduler.RemoveJobFromTask @taskId = @taskId;
		end try
		begin catch
			/* Swallow error - we don't want to take out the whole run if a single task fails to create */
		end catch
		set @id += 1;
	END
end
go