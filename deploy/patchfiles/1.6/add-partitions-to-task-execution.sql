alter procedure scheduler.ExecuteTask
	@taskId int = null
	,@identifier nvarchar(128) = null
as
begin
    return
end
go

if not exists 
(
select 	TOP 1 1
from sys.partitions p
join sys.objects o on o.object_id = p.object_id
JOIN sys.schemas AS s on s.schema_id = o.schema_id
join sys.indexes i on p.object_id = i.object_id and p.index_id = i.index_id
join sys.data_spaces ds on i.data_space_id = ds.data_space_id
join sys.partition_schemes ps on ds.data_space_id = ps.data_space_id
JOIN sys.partition_functions pf on ps.function_id = pf.function_id

where s.name = 'scheduler' and o.name = 'TaskExecution' and ps.name ='PS_RingBufferByMonthOfYear' and pf.name ='PF_RingBufferByMonthOfYear'
)
begin
    drop table if exists scheduler.TaskExecutionOld;

    if ( exists( select * from sys.partition_schemes where name = 'PS_RingBufferByMonthOfYear' ) )
    begin
        drop partition scheme PS_RingBufferByMonthOfYear;
    end
    
    if ( exists( select * from sys.partition_functions where name = 'PF_RingBufferByMonthOfYear' ) )
    begin
        drop partition function PF_RingBufferByMonthOfYear;
    end
    
    create partition function PF_RingBufferByMonthOfYear (tinyint)
    as range left for values (1,2,3,4,5,6,7,8,9,10,11,12);
    
     
    create partition scheme PS_RingBufferByMonthOfYear 
    as partition PF_RingBufferByMonthOfYear all to ([primary]);

    if object_id('scheduler.taskexecution', 'U') is not null
        BEGIN
        EXEC sp_rename @objname = '[scheduler].[DF_TaskExecution_IsError]',@newname = 'DF_TaskExecution_IsErrorOld', @objtype = 'object' ;
        EXEC sp_rename @objname = '[scheduler].[DF_TaskExecution_StartDateTime]',@newname = 'DF_TaskExecution_StartDateTimeOld',@objtype = 'object';
        EXEC sp_rename @objname = N'scheduler.TaskExecution.PK_TaskExecution', @newname = N'PK_TaskExecutionOld'
        EXEC sp_rename @objname = 'scheduler.TaskExecution',@newname = 'TaskExecutionOld';

        end

    create table scheduler.TaskExecution
    (
    	ExecutionId int identity(1,1) not null
    	,TaskId int not null
    	,StartDateTime datetime2(3) not null constraint DF_TaskExecution_StartDateTime default getutcdate()
    	,EndDateTime datetime2(3) null
    	,IsError bit not null constraint DF_TaskExecution_IsError default (0)
    	,ResultMessage nvarchar(max) null
        ,MonthOfYear as cast(month (StartDateTime) as tinyint) persisted not null
    	,constraint PK_TaskExecution primary key clustered (MonthOfYear,ExecutionId) with (data_compression = page) on PS_RingBufferByMonthOfYear (MonthOfYear)
    );
end 
go
