
create or alter view scheduler.TaskConfig 
as
select  
    TaskId,
    Identifier,
    (select 
        TaskId,
        Identifier,
        TSQLCommand,
        StartTime,
        FrequencyType,
        FrequencyTypeDesc,
        FrequencyInterval,
        NotifyOnFailureOperator,
        IsNotifyOnFailure,
        IsEnabled,
        IsDeleted,
        SysStartTime,
        SysEndTime 
    for json path, without_array_wrapper) as Config
from scheduler.Task
go
