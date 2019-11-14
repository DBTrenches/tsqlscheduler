Function Install-ReplicaStatusJob 
{
    [cmdletbinding()]
    Param (
        [string] $Server
        ,[string] $Database
        ,[string] $NotifyOperator
    )

    $jobIdentifier = "RecordReplicaStatus"
    $command = "exec $Database.scheduler.UpdateReplicaStatus"
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
    ,IsCachedRoleCheck
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
    ,2
    ,0
    ,1
    ,0
)
"

    Invoke-SqlCmd -ServerInstance $Server -Database $Database -Query $query
    Invoke-SqlCmd -ServerInstance $Server -Database $Database -Query "exec scheduler.CreateJobFromTask @taskUid = '$taskUid', @overwriteExisting = 1;"
}
