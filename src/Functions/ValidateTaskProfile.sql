
create or alter function scheduler.ValidateTaskProfile (
    @taskId            int,
    @jobIdentifier     sysname,
    @tsqlCommand       nvarchar(max),
    @startTime         time,
    @frequencyType     tinyint,
    @frequencyInterval smallint,
    @notifyOperator    sysname,
    @isNotifyOnFailure bit,
    @overwriteExisting bit = 0
)
returns @IsTaskValid table (
    taskId                  int,
    Identifier              sysname,
    IsValidTask             bit not null,
    Comments                nvarchar(max),
    TSQLCommand             nvarchar(max),
    StartTime               time,
    FrequencyType           tinyint,
    FrequencyTypeDesc       varchar(6),
    FrequencyInterval       smallint,
    NotifyOnFailureOperator nvarchar(128),
    IsNotifyOnFailure       bit,
    ExistingJobID           uniqueidentifier
)
as
begin
    declare @NOT_VALID bit = 0;

    declare @taskAttributes table (
        id int not null identity primary key,
        msg nvarchar(max) not null,
        isValid bit not null
    );

    declare @frequencyTypeDesc varchar(6);
    select @frequencyTypeDesc = scheduler.FrequencyDescFromType( @frequencyType );

    	/* Validate parameters for basic correctness */
    begin
        if @jobIdentifier is null
    	begin
            insert @taskAttributes ( msg, isValid )
            select 
                msg='@jobName/@jobIdentifier must be specified', 
                isValid=@NOT_VALID; 
        end;
    
    	if @tsqlCommand is null or @tsqlCommand = ''
    	begin
    		insert @taskAttributes ( msg, isValid )
            select 
                msg='@tsqlCommand must be specified', 
                isValid=@NOT_VALID; 
    	end
    
    	if @frequencyType is null
    	begin
    		insert @taskAttributes ( msg, isValid )
            select 
                msg='@frequencyType must be specified', 
                isValid=@NOT_VALID; 
    	end
    
    	if @frequencyInterval is null
    	begin
    		insert @taskAttributes ( msg, isValid )
            select 
                msg='@frequencyInterval must be specified', 
                isValid=@NOT_VALID; 
    	end
    
    	if @startTime is null
    	begin
    		insert @taskAttributes ( msg, isValid )
            select 
                msg='@startTime must be specified', 
                isValid=@NOT_VALID; 
    	end
    
    	if @notifyOperator is null
    	begin
    		insert @taskAttributes ( msg, isValid )
            select 
                msg='@notifyOperator must be specified', 
                isValid=@NOT_VALID; 
    	end
    end

	    /* Extended validation */
    begin
        declare @FREQUENCY_DAY varchar(6) = 'day'
    		,@FREQUENCY_HOUR varchar(6) = 'hour'
    		,@FREQUENCY_MINUTE varchar(6) = 'minute'
    		,@FREQUENCY_SECOND varchar(6) = 'second'
    
    	if @frequencyTypeDesc not in (@FREQUENCY_DAY, @FREQUENCY_HOUR, @FREQUENCY_MINUTE, @FREQUENCY_SECOND)
            or @frequencyTypeDesc is null
    	begin
    		insert @taskAttributes ( msg, isValid )
            select 
                msg=formatmessage('@frequencyType/desc of [%i]/[%s] is invalid - must be one of: day, hour, minute, second',@frequencyType,@frequencyTypeDesc), 
                isValid=@NOT_VALID; 
    	end
    
    	if @frequencyTypeDesc = @FREQUENCY_DAY and @frequencyInterval <> 0
    	begin
    		insert @taskAttributes ( msg, isValid )
            select 
                msg='Daily frequency only supports an interval of 0 (once per day)', 
                isValid=@NOT_VALID; 
    	end
    
    	if @frequencyTypeDesc = @FREQUENCY_HOUR and @frequencyInterval > 23
    	begin
    		insert @taskAttributes ( msg, isValid )
            select 
                msg='Hourly frequency with an interval of 24 hours or more are not supported', 
                isValid=@NOT_VALID; 
    	end
    
    	if @frequencyTypeDesc = @FREQUENCY_HOUR and not @frequencyInterval between 1 and 23
    	begin
    		insert @taskAttributes ( msg, isValid )
            select 
                msg='Hourly frequency requires an interval between 1 and 23', 
                isValid=@NOT_VALID; 
    	end
    
    	if @frequencyTypeDesc = @FREQUENCY_MINUTE and not @frequencyInterval between 1 and 3599
    	begin
    		insert @taskAttributes ( msg, isValid )
            select 
                msg='Minute frequency requires an interval between 1 and 3599 (1 minute to 1 day)', 
                isValid=@NOT_VALID; 
    	end
    
    	if @frequencyTypeDesc = @FREQUENCY_SECOND and not @frequencyInterval between 1 and 3599
    	begin
    		insert @taskAttributes ( msg, isValid )
            select 
                msg='Second frequency requires an interval between 1 and 3599 (1 second to 1 hour)', 
                isValid=@NOT_VALID; 
    	end
    
    	/* Validate job does not already exist (if overwrite is not specified)
    	    Validate operator exists 
    	*/
    
        if exists ( select 1 
                    from scheduler.Task t
                    where t.Identifier = @jobIdentifier )
        begin;
    		insert @taskAttributes ( msg, isValid )
            select 
                msg=formatmessage('Specified task name of [%s] already exists',@jobIdentifier), 
                isValid=@overwriteExisting; -- not an error for overwrite            
        end;

    	declare @existingJobId uniqueidentifier;
    	select @existingJobId = s.job_id
    	from msdb.dbo.sysjobs as s
    	where s.[name] = @jobIdentifier;
    
    	if @existingJobId is not null
    	begin
    		insert @taskAttributes ( msg, isValid )
            select 
                msg=formatmessage('Specified job name of [%s] already exists',@jobIdentifier), 
                isValid=@overwriteExisting; -- not an error for overwrite
    	end
    
    	if not exists (
    		select 1
    		from msdb.dbo.sysoperators as o
    		where o.name = @notifyOperator
    	)
    	begin
    		insert @taskAttributes ( msg, isValid )
            select 
                msg=formatmessage('Specified @notifyOperator name [%s] does not exist',@notifyOperator), 
                isValid=@NOT_VALID;
    	end
    
    end
    declare
        @IsValidTask bit = 1,
        @ErrorMsg    nvarchar(max) = N'';

    select @IsValidTask &= ta.isValid 
    from @taskAttributes ta;

    with err (msg) as (
        select msg 
        from @taskAttributes ta 
        for json path
    )
    select @ErrorMsg = msg
    from err;

    insert @IsTaskValid ( 
        taskId,
        Identifier,
        IsValidTask,
        Comments,
        TSQLCommand,
        StartTime,
        FrequencyType,
        FrequencyTypeDesc,
        FrequencyInterval,
        NotifyOnFailureOperator,
        IsNotifyOnFailure,
        ExistingJobID )
    values ( 
        @taskId, 
        @jobIdentifier, 
        @IsValidTask, 
        @ErrorMsg, 
        @tsqlCommand, 
        @startTime, 
        @frequencyType, 
        @frequencyTypeDesc,
        @frequencyInterval, 
        @notifyOperator, 
        @isNotifyOnFailure,
        @existingJobId );

    return
end;
go
