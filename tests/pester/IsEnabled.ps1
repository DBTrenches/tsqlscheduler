function IsEnabled($enabled) {
    # Cleanup
    $query = "delete from scheduler.task; truncate table scheduler.taskexecution;"
    Invoke-Sqlcmd -ServerInstance . -Database tsqlscheduler -Query $query

    # Create task
    $query = "insert into scheduler.task (identifier, tsqlcommand, starttime, frequencytype, frequencyinterval, notifyonfailureoperator, IsEnabled) values ('IsEnabledExecution', 'select @@servername', '00:00', 1, 0, 'Test Operator', '$enabled');"
    Invoke-Sqlcmd -ServerInstance . -Database tsqlscheduler -Query $query

    # Execute task
    $query = "exec scheduler.ExecuteTask @identifier = 'IsEnabledExecution';"
    Invoke-Sqlcmd -ServerInstance . -Database tsqlscheduler -Query $query | out-null

    # Verify task completes
    $query = "select count(*) as ExecutionCount from scheduler.Task as t join scheduler.TaskExecution as te on te.TaskId = t.TaskId where t.Identifier = 'IsEnabledExecution'"
    $result = Invoke-Sqlcmd -ServerInstance . -Database tsqlscheduler -Query $query

    return $result.ExecutionCount
}
