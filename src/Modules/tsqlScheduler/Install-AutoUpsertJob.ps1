Function Install-AutoUpsertJob 
{
    [cmdletbinding()]
    Param (
        [string] $Server
        ,[string] $Database
        ,[string] $TargetDatabase
        ,[string] $NotifyOperator
    )

    $jobIdentifier = "$TargetDatabase-UpsertJobsForAllTasks"
    $command = "exec $TargetDatabase.scheduler.UpsertJobsForAllTasks;"
    $taskUid = [Guid]::NewGuid().ToString()

    $query = "
insert into scheduler.Task
(
    TaskUid
    ,Identifier
    ,TSQLCommand
    ,StartTime
    ,Frequency
    ,FrequencyInterval
    ,NotifyOnFailureOperator
    ,NotifyLevelEventLog 
    ,IsNotifyOnFailure
    ,IsEnabled
)
values
(
    '$taskUid'
    ,'$jobIdentifier'
    ,N'$command'
    ,'00:00'
    ,'Minute'
    ,1
    ,'$NotifyOperator'
    ,'OnFailure'
    ,0
    ,1
)
"
    Invoke-SqlCmd -ServerInstance $Server -Database $Database -Query $query
    Invoke-SqlCmd -ServerInstance $Server -Database $Database -Query "exec scheduler.CreateJobFromTask @taskUid = '$taskUid', @overwriteExisting = 1;"
}
