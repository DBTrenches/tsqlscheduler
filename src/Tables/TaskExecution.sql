create partition function PF_RingBufferByMonthOfYear (tinyint)
as range left for values (1,2,3,4,5,6,7,8,9,10,11,12);
go

create partition scheme PS_RingBufferByMonthOfYear 
as partition PF_RingBufferByMonthOfYear all to ([primary]);
go

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
go
