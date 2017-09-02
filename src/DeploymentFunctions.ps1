Function Install-SchedulerSolution 
{
    [cmdletbinding()]
    Param (
        $server = "localhost"
        ,$database = "tsqlscheduler"
        # False = AG deployment
        ,$agMode = $false 
    )

    $files = @('./Schema/scheduler.sql')

    if($agMode) {
        $files += './Tables/Task_AG.sql'    
    } else {
        $files += './Tables/Task_Standalone.sql'
    }
    $files += './Tables/TaskExecution.sql'
    $files += './Functions/GetAvailabilityGroupRole.sql'
    $files += './Functions/GetVersion.sql'
    $files += './Procedures/SetContextInfo.sql'
    $files += './Procedures/CreateAgentJob.sql'
    $files += './Procedures/CreateJobFromTask.sql'
    $files += './Procedures/DeleteAgentJob.sql'
    $files += './Procedures/ExecuteTask.sql'
    $files += './Procedures/RemoveJobFromTask.sql'
    $files += './Procedures/UpsertJobsForAllTasks.sql'
    $files += './Views/CurrentlyExecutingTasks.sql'

    $files | foreach-object { 
        Write-Verbose $_
        Invoke-SqlCmd -ServerInstance $server -Database $database -InputFile $_ 
    }

    $instanceGuid = [System.Guid]::NewGuid().ToString()
    $instanceFunction = @"
    create or alter function scheduler.GetInstanceId()
    returns table
    as
    return (
        select cast('$instanceGuid' as uniqueidentifier) as Id
    );
"@

    Invoke-SqlCmd -ServerInstance $server -Database $database -Query $instanceFunction
}

Function Install-AutoUpsertJob (
        $Server = "localhost"
        ,$Database = "tsqlscheduler"
        ,$TargetDatabase = "tsqlscheduler"
        ,$NotifyOperator = "Test Operator"
)
{
    $jobIdentifier = $TargetDatabase + "-UpsertJobsForAllTasks"
    $query = "
        insert into scheduler.Task
        ( Identifier, TSQLCommand, StartTime, FrequencyType, FrequencyInterval, NotifyOnFailureOperator, IsNotifyOnFailure )
        values
        ( '$jobIdentifier', 'exec $TargetDatabase.scheduler.UpsertJobsForAllTasks', '00:00', 3, 10, '$NotifyOperator', 0 );"

    Invoke-SqlCmd -ServerInstance $Server -Database $Database -Query $query
    Invoke-SqlCmd -ServerInstance $Server -Database $Database -Query "exec scheduler.CreateJobFromTask @identifier = '$jobIdentifier', @overwriteExisting = 1;"
}