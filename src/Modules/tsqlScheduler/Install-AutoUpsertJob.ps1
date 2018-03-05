Function Install-AutoUpsertJob 
{
    [cmdletbinding()]
    Param (
        [string] $Server
        ,[string] $Database
        ,[string] $TargetDatabase
        ,[string] $NotifyOperator
    )

    # conform to naming convention of $ownLocation-$target-$task
    # but do not double-prefix self-reference/standalone AutUpsert jobs
    if($Database -eq $TargetDatabase){
        $prefix = $TargetDatabase
    }else{
        $prefix = $Database + "-" + $TargetDatabase
    }

    $jobIdentifier = $prefix + "-UpsertJobsForAllTasks"
    $query = "
exec scheduler.UpsertTask
    @action = 'INSERT', 
    @jobIdentifier = '$jobIdentifier', 
    @tsqlCommand = N'exec $TargetDatabase.scheduler.UpsertJobsForAllTasks;', 
    @startTime = '00:00', 
    @frequencyType = 3, 
    @frequencyInterval = 1, 
    @notifyOperator = '$NotifyOperator',
    @notifyLevelEventlog = 2, 
    @isNotifyOnFailure = 0,
    @overwriteExisting = 1;" # allow error-free redeploy of same AG after logical delete of local upsert job

    Invoke-SqlCmd -ServerInstance $Server -Database $Database -Query $query
    Invoke-SqlCmd -ServerInstance $Server -Database $Database -Query "exec scheduler.CreateJobFromTask @identifier = '$jobIdentifier', @overwriteExisting = 1;"
}
