create or alter procedure scheduler.DeleteAgentJob
    @taskUid uniqueidentifier

as
begin
    set xact_abort on;
    set nocount on;
    
    /* Validate parameters for basic correctness */
    if @taskUid is null
    begin
        ;throw 50000, '@taskUid must be specified', 1;
    end

    declare @existingJobId uniqueidentifier;
    select @existingJobId = j.job_id
    from scheduler.AgentJobsForCurrentInstance as j
    where j.TaskUid = @taskUid

    if @existingJobId is null 
    begin
          ;throw 50000, 'Specified job does not exist', 1;
          RETURN;
    end
       
    declare @schedule_Id int;

    select @schedule_Id=s.schedule_id 
    from  msdb.dbo.sysschedules s 
    join  msdb.dbo.sysjobschedules sj
    on    s.schedule_id=sj.schedule_id
    where sj.job_id=@existingJobId

    /* Delete schedule if exists*/
    IF @schedule_Id is not null
    begin
          EXEC msdb.dbo.sp_delete_schedule @schedule_id=@schedule_id, @force_delete = 1
    end

    /* Delete Job*/
    exec msdb.dbo.sp_delete_job @job_id = @existingJobId;
end