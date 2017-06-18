$server = "localhost";
$database = "tsqlscheduler"

$files = @('./Schema/scheduler.sql'
            ,'./Tables/Task.sql'
            ,'./Tables/TaskExecution.sql'
            ,'./Functions/GetAvailabilityGroupRole.sql'
            ,'./Procedures/CreateAgentJob.sql'
            ,'./Procedures/CreateJobFromTask.sql'
            ,'./Procedures/DeleteAgentJob.sql'
            ,'./Procedures/ExecuteTask.sql'
            ,'./Procedures/RemoveJobFromTask.sql'
            ,'./Procedures/UpsertJobsForAllTasks.sql'
            )

$files | foreach-object { Invoke-SqlCmd -ServerInstance $server -Database $database -InputFile $_ }
