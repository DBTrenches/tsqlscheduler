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
	,AvailabilityGroup nvarchar(128) not null
	,IsCachedRoleCheck bit not null
    ,IsDeleted bit constraint DF_IsDeleted default (0)
	,SysStartTime datetime2 generated always as row start not null
	,SysEndTime datetime2 generated always as row end not NULL
	,period for system_time (SysStartTime, SysEndTime)
	,constraint PK_Task primary key clustered (TaskId) with (data_compression = page)
	,constraint UQ_Task_Name unique nonclustered (Identifier) with (data_compression = page)
	,constraint CK_FrequencyInterval CHECK ((FrequencyType=1 AND FrequencyInterval=0) OR (FrequencyType IN (2,3,4) AND FrequencyInterval>0))
) with (system_versioning = on (history_table = scheduler.TaskHistory))
GO