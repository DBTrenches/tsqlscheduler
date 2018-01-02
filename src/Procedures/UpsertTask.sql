
create or alter proc scheduler.UpsertTask
    @action            varchar(6),
    @taskId            int           = null,
    @jobIdentifier     sysname       = null,
    @tsqlCommand       nvarchar(max) = null,
    @startTime         time          = null,
    @frequencyType     tinyint       = null,
    @frequencyTypeDesc varchar(6)    = null,
    @frequencyInterval smallint      = null,
    @notifyOperator    sysname       = null,
    @isNotifyOnFailure bit           = 1,
    @IsEnabled         bit           = 1,
--    @IsCachedRoleCheck bit           = 1,
    @IsDeleted         bit           = 0,
    @overwriteExisting bit           = 0
as
begin;
    set nocount on;
    set xact_abort on;

        /* Validate params */
    declare 
        @frequencyTypeNum tinyint = 
            coalesce(
                 @frequencyType
                ,scheduler.FrequencyTypeFromDesc( @frequencyTypeDesc ) 
            ),
        @IsValidTask bit = 1,
        @Comments nvarchar(max),
        @ErrorMsg nvarchar(max) = N'',
        @ErrCount int = 0;

    if @taskId is null 
        and @jobIdentifier is null
    begin;
        select
            @ErrCount += 1,
            @ErrorMsg += 'At least one of @taskId or @jobIdentifier must be specified. ' + char(10);
    end;
 
    if @taskId is not null 
        and @action = 'INSERT'
    begin;
         select
            @ErrCount += 1,
            @ErrorMsg += '@taskId may not be specified if requested @action is [INSERT]. ' + char(10);
    end;

    if @action not in ('INSERT','UPDATE','DELETE') or @action is null
    begin;
        select 
            @ErrCount += 1,
            @ErrorMsg += formatmessage('@action supplied value of [%s] is invalid. Allowed values for @action are [Insert, Update, Delete]. ',@action) + char(10);
    end;
    else if @action = 'UPDATE' 
    begin;
        set @overwriteExisting = 1;
    end;

    if @action = 'INSERT' 
        and @overwriteExisting = 1
        and exists ( select 1
                     from scheduler.Task t
                     where t.Identifier = @jobIdentifier )
    begin;
        select 
            @action = 'UPDATE',
            @taskId = TaskId
        from scheduler.Task
        where Identifier = @jobIdentifier;
    end;

    if @ErrCount > 0
    begin;
        set @ErrorMsg = 'Errors found in pre-validation as follows: ' + char(10) + @ErrorMsg;
        throw 50000, @ErrorMsg, 1;
    end;

        /* skip validation for simple deletes */
    if @action = 'DELETE' goto DEL;

    select
        @IsValidTask = tv.IsValidTask,
        @Comments = tv.Comments
    from scheduler.ValidateTaskProfile (
        @taskId,
        @jobIdentifier,
        @tsqlCommand,
        @startTime,
        @frequencyTypeNum,
        @frequencyInterval,
        @notifyOperator,
        @isNotifyOnFailure,
        @overwriteExisting
    ) tv;

    if @IsValidTask = 0
    begin
        with errors (msg) as (
            select msg
            from openjson(@Comments) 
            with (msg nvarchar(max) 'strict $.msg') 
        )
        select @ErrorMsg += msg+char(10)
        from errors;

        throw 50000, @ErrorMsg, 1;
    end;

    if @action = 'INSERT'
    begin;
        exec scheduler.CreateTask @jobIdentifier     = @jobIdentifier,
                                  @tsqlCommand       = @tsqlCommand,
                                  @startTime         = @startTime,
                                  @frequencyType     = @frequencyTypeNum,
                                  @frequencyInterval = @frequencyInterval,
                                  @notifyOperator    = @notifyOperator,
                                  @isNotifyOnFailure = @isNotifyOnFailure,
                                  @IsEnabled         = @IsEnabled,
--                                  @IsCachedRoleCheck = @IsCachedRoleCheck,
                                  @IsDeleted         = @IsDeleted;

        return;
    end;
    if @action = 'UPDATE'
    begin;
        exec scheduler.UpdateTask @taskId            = @taskId,
                                  @jobIdentifier     = @jobIdentifier,
                                  @tsqlCommand       = @tsqlCommand,
                                  @startTime         = @startTime,
                                  @frequencyType     = @frequencyTypeNum,
                                  @frequencyInterval = @frequencyInterval,
                                  @notifyOperator    = @notifyOperator,
                                  @isNotifyOnFailure = @isNotifyOnFailure,
                                  @IsEnabled         = @IsEnabled,
--                                  @IsCachedRoleCheck = @IsCachedRoleCheck,
                                  @IsDeleted         = @IsDeleted;

        return;
    end;
    if @action = 'DELETE'
    begin;
DEL:
        declare @task sysname = coalesce(@taskId,@jobIdentifier);
        exec scheduler.DeleteTask 
            @task = @task; 

        return;
    end;
end;
go
