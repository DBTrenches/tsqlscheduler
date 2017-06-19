Function Deploy-SchedulerSolution (
    $server = "localhost"
    ,$database = "tsqlscheduler"
    # False = AG deployment
    ,$agMode = $false 
)
{
    $files = @('./Schema/scheduler.sql')

    if($agMode) {
        $files += './Tables/Task_AG.sql'    
    } else {
        $files += './Tables/Task_Standalone.sql'
    }
    $files += './Tables/TaskExecution.sql'
    $files += './Functions/GetAvailabilityGroupRole.sql'
    $files += './Procedures/CreateAgentJob.sql'
    $files += './Procedures/CreateJobFromTask.sql'
    $files += './Procedures/DeleteAgentJob.sql'
    $files += './Procedures/ExecuteTask.sql'
    $files += './Procedures/RemoveJobFromTask.sql'
    $files += './Procedures/UpsertJobsForAllTasks.sql'

    $files | foreach-object { Invoke-SqlCmd -ServerInstance $server -Database $database -InputFile $_ }
}