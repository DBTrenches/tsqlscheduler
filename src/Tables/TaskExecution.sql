create table scheduler.TaskExecution
(
	ExecutionId int identity(1,1) not null
	,TaskId int not null
	,StartDateTime datetime2(3) not null constraint DF_TaskExecution_StartDateTime default getutcdate()
	,EndDateTime datetime2(3) null
	,IsError bit not null constraint DF_TaskExecution_IsError default (0)
	,ResultMessage nvarchar(max) null
	,constraint PK_TaskExecution primary key clustered (ExecutionId) with (data_compression = page)
);
go