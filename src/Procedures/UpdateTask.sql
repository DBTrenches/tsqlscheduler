
create or alter proc scheduler.UpdateTask  
    @taskId            int,
    @jobIdentifier     sysname,
    @tsqlCommand       nvarchar(max),
    @startTime         time,
    @frequencyType     tinyint,
    @frequencyInterval smallint,
    @notifyOperator    sysname,
    @isNotifyOnFailure bit = 1,
    @IsEnabled         bit = 0,
    @IsDeleted         bit = 1
as
begin
    set nocount on;
    set xact_abort on;
    set lock_timeout 10000; -- escape long running jobs during rename attempt
    set deadlock_priority high; -- prioritise user command over scheduled update
    
    declare 
        @newName sysname = @jobIdentifier,
        @isRename bit = 0,
        @ErrorMsg nvarchar(max) = 'Task update could not be completed and was aborted.';

    if @taskId is null 
    begin;
        throw 50000, '@taskId must be specified for task update.', 1;
    end;

    if not exists ( select 1 
                    from scheduler.Task t 
                    where t.TaskId = @taskId )
    begin;
        set @ErrorMsg = formatmessage('Task ID of [%i] was not found. Update requires a valid task ID',@taskId);
        throw 50000, @ErrorMsg, 1;
    end;

    if exists ( select 1 
                from scheduler.Task t
                where t.TaskId = @taskId
                    and t.Identifier <> @newName )
    begin;
        set @isRename = 1;
    end;

    begin tran;

    begin try;
        update scheduler.Task set
            TSQLCommand             = @tsqlCommand,
            StartTime               = @startTime,
            FrequencyType           = @frequencyType,
            FrequencyInterval       = @frequencyInterval,
            NotifyOnFailureOperator = @notifyOperator,
            IsNotifyOnFailure       = @isNotifyOnFailure,
            IsEnabled               = @IsEnabled,
            IsDeleted               = @IsDeleted
        where TaskId = @taskId;
    
        if @isRename = 1
        begin 
            select @jobIdentifier = t.Identifier
            from scheduler.Task t
            where t.TaskId = @taskId;

            update scheduler.Task set
                IsDeleted = 1
            where TaskId = @taskId;
    
            exec scheduler.DeleteAgentJob @jobName = @jobIdentifier;
    
            update scheduler.Task set
                Identifier = @newName,
                IsDeleted = @IsDeleted -- allow for rename & deletion in same update
            where taskId = @taskId;
    
            exec scheduler.CreateJobFromTask @taskId = @taskId;
        end;
    
        commit tran;
    end try begin catch;
        rollback tran;
        
        set @ErrorMsg += ' The message returned was: ' + char(10) + isnull(error_message(),'');

        throw 50000, @ErrorMsg, 1;
    end catch;

end;
go
