
create or alter view scheduler.TaskConfig 
as
select  
    TaskUid,
    Identifier,
    (select 
        TaskUid,
        Identifier,
        TSQLCommand,
        StartTime,
        Frequency
        FrequencyInterval,
        NotifyOnFailureOperator,
        IsNotifyOnFailure,
        IsEnabled,
        IsDeleted,
        NotifyLevelEventlog,
        SysStartTime,
        SysEndTime 
    for json path, without_array_wrapper) as Config
from scheduler.Task
go
