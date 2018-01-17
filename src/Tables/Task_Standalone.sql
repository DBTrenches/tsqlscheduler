create table scheduler.Task
(
	TaskId int identity(1,1) not null
	,Identifier nvarchar(128) not null
	,TSQLCommand nvarchar(max) not null
	,StartTime time not null
	,FrequencyType tinyint not null
	,FrequencyTypeDesc as case FrequencyType when 1 then 'Day' when 2 then 'Hour' when 3 then 'Minute' when 4 then 'Second' end
	,FrequencyInterval smallint not null
	,NotifyOnFailureOperator nvarchar(128) not null
	,IsNotifyOnFailure bit not null constraint DF_Task_IsNotifyOnFailure default (1)
	,IsEnabled bit not null constraint DF_Task_IsEnabled default (1)
    ,IsDeleted bit not null constraint DF_IsDeleted default (0)
	,NotifyLevelEventlog int constraint DF_Task_NotifyLevelEventlog default (2)
	,SysStartTime datetime2 generated always as row start not null
	,SysEndTime datetime2 generated always as row end not NULL
	,period for system_time (SysStartTime, SysEndTime)
	,constraint PK_Task primary key clustered (TaskId) with (data_compression = page)
	,constraint UQ_Task_Name unique nonclustered (Identifier) with (data_compression = page)
	,constraint CK_FrequencyInterval CHECK ((FrequencyType=1 AND FrequencyInterval=0) OR (FrequencyType IN (2,3,4) AND FrequencyInterval>0))
	,constraint chk_Task_JobNamePrefacedByLocalDB check (substring(Identifier,(1),len(scheduler.GetDatabase()))=scheduler.GetDatabase())
) with (system_versioning = on (history_table = scheduler.TaskHistory))
GO