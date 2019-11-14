
create or alter proc scheduler.UpsertTask
    @action            varchar(6),
    @taskUid           uniqueidentifier = null,
    @jobIdentifier     sysname       = null,
    @tsqlCommand       nvarchar(max) = null,
    @startTime         time          = null,
    @frequency         varchar(6)    = null,
    @frequencyInterval smallint      = null,
    @notifyOperator    sysname       = null,
    @isNotifyOnFailure bit           = 1,
    @notifyLevelEventlog int         = 2,
    @IsEnabled         bit           = 1,
    @IsDeleted         bit           = 0,
    @overwriteExisting bit           = 0
as
begin;
    set nocount on;
    set xact_abort on;

    -- todo, this

--     /* Validate params */
--     declare 
--         @frequencyTypeNum tinyint = 
--             coalesce(
--                  @frequencyType
--                 ,scheduler.FrequencyTypeFromDesc( @frequencyTypeDesc ) 
--             ),
--         @IsValidTask bit = 1,
--         @Comments nvarchar(max),
--         @ErrorMsg nvarchar(max) = N'',
--         @ErrCount int = 0;

--     if @taskUid is null 
--         and @jobIdentifier is null
--     begin;
--         select
--             @ErrCount += 1,
--             @ErrorMsg += 'At least one of @taskUid or @jobIdentifier must be specified. ' + char(10);
--     end;

--     if @action not in ('INSERT','UPDATE','DELETE') or @action is null
--     begin;
--         select 
--             @ErrCount += 1,
--             @ErrorMsg += formatmessage('@action supplied value of [%s] is invalid. Allowed values for @action are [Insert, Update, Delete]. ',@action) + char(10);
--     end;
--     else if @action = 'UPDATE' 
--     begin;
--         set @overwriteExisting = 1;
--     end;

--     if @action = 'INSERT' 
--         and @overwriteExisting = 1
--         and exists ( select 1
--                      from scheduler.Task t
--                      where t.taskUid = @taskUid )
--     begin;
--         set @action = 'UPDATE'
--     end;

--     if @ErrCount > 0
--     begin;
--         set @ErrorMsg = 'Errors found in pre-validation as follows: ' + char(10) + @ErrorMsg;
--         throw 50000, @ErrorMsg, 1;
--     end;

--     /* skip validation for simple deletes */
--     if @action = 'DELETE' goto DEL;

--     select
--         @IsValidTask = tv.IsValidTask,
--         @Comments = tv.Comments
--     from scheduler.ValidateTaskProfile (
--         @taskUid,
--         @jobIdentifier,
--         @tsqlCommand,
--         @startTime,
--         @frequencyTypeNum,
--         @frequencyInterval,
--         @notifyOperator,
--         @notifyLevelEventlog,
--         @isNotifyOnFailure,
--         @overwriteExisting
--     ) tv;

--     if @IsValidTask = 0
--     begin
--         with errors (msg) as (
--             select msg
--             from openjson(@Comments) 
--             with (msg nvarchar(max) 'strict $.msg') 
--         )
--         select @ErrorMsg += msg+char(10)
--         from errors;

--         throw 50000, @ErrorMsg, 1;
--     end;

--     if @action = 'INSERT'
--     begin;
--         exec scheduler.CreateTask @jobIdentifier       = @jobIdentifier,
--                                   @taskUid             = @taskUid,
--                                   @tsqlCommand         = @tsqlCommand,
--                                   @startTime           = @startTime,
--                                   @frequencyType       = @frequencyTypeNum,
--                                   @frequencyInterval   = @frequencyInterval,
--                                   @notifyOperator      = @notifyOperator,
--                                   @notifyLevelEventlog = @notifyLevelEventlog,
--                                   @isNotifyOnFailure   = @isNotifyOnFailure,
--                                   @IsEnabled           = @IsEnabled,
--                                   @IsDeleted           = @IsDeleted;

--         return;
--     end;
--     if @action = 'UPDATE'
--     begin;
--         exec scheduler.UpdateTask @taskUid             = @taskUid,
--                                   @jobIdentifier       = @jobIdentifier,
--                                   @tsqlCommand         = @tsqlCommand,
--                                   @startTime           = @startTime,
--                                   @frequencyType       = @frequencyTypeNum,
--                                   @frequencyInterval   = @frequencyInterval,
--                                   @notifyOperator      = @notifyOperator,
--                                   @notifyLevelEventlog = @notifyLevelEventlog,
--                                   @isNotifyOnFailure   = @isNotifyOnFailure,
--                                   @IsEnabled           = @IsEnabled,
--                                   @IsDeleted           = @IsDeleted;

--         return;
--     end;
--     if @action = 'DELETE'
--     begin;
-- DEL:
--         exec scheduler.DeleteTask @taskUid = @taskUid

--         return;
--     end;
end;
go
