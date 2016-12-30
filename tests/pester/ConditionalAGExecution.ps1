function ConditionalAGExecution_PrimaryExecutes {
    # Cleanup
    Invoke-Sqlcmd -ServerInstance . -Database tsqlscheduler -Query "delete from scheduler.task; truncate table scheduler.taskexecution;"

    # Create task
    Invoke-Sqlcmd -ServerInstance . -Database tsqlscheduler -Query "insert into scheduler.task (identifier, tsqlcommand, starttime, frequencytype, frequencyinterval, notifyonfailureoperator, availabilitygroup) values ('ConditionalAGExecution', 'select @@servername', '00:00', 1, 0, 'Test Operator', 'ALWAYS_PRIMARY');"

    # Execute task
    Invoke-Sqlcmd -ServerInstance . -Database tsqlscheduler -Query "exec scheduler.ExecuteTask @identifier = 'ConditionalAGExecution';" | out-null

    # Verify task completes
    $result = Invoke-Sqlcmd -ServerInstance . -Database tsqlscheduler -Query "select count(*) as ExecutionCount from scheduler.Task as t join scheduler.TaskExecution as te on te.TaskId = t.TaskId where t.Identifier = 'ConditionalAGExecution'"

    return $result.ExecutionCount
}

function ConditionalAGExecution_SecondaryDoesNotExecute {
    # Cleanup
    Invoke-Sqlcmd -ServerInstance . -Database tsqlscheduler -Query "delete from scheduler.task; truncate table scheduler.taskexecution;"

    # Create task
    Invoke-Sqlcmd -ServerInstance . -Database tsqlscheduler -Query "insert into scheduler.task (identifier, tsqlcommand, starttime, frequencytype, frequencyinterval, notifyonfailureoperator, availabilitygroup) values ('ConditionalAGExecution', 'select @@servername', '00:00', 1, 0, 'Test Operator', 'NEVER_PRIMARY');"

    # Execute task
    Invoke-Sqlcmd -ServerInstance . -Database tsqlscheduler -Query "exec scheduler.ExecuteTask @identifier = 'ConditionalAGExecution';" | out-null

    # Verify task completes
    $result = Invoke-Sqlcmd -ServerInstance . -Database tsqlscheduler -Query "select count(*) as ExecutionCount from scheduler.Task as t join scheduler.TaskExecution as te on te.TaskId = t.TaskId where t.Identifier = 'ConditionalAGExecution'"

    return $result.ExecutionCount
}

function ConditionalAGExecution_NoAGDoesExecute {
    # Cleanup
    Invoke-Sqlcmd -ServerInstance . -Database tsqlscheduler -Query "delete from scheduler.task; truncate table scheduler.taskexecution;"

    # Create task
    Invoke-Sqlcmd -ServerInstance . -Database tsqlscheduler -Query "insert into scheduler.task (identifier, tsqlcommand, starttime, frequencytype, frequencyinterval, notifyonfailureoperator, availabilitygroup) values ('ConditionalAGExecution', 'select @@servername', '00:00', 1, 0, 'Test Operator', null);"

    # Execute task
    Invoke-Sqlcmd -ServerInstance . -Database tsqlscheduler -Query "exec scheduler.ExecuteTask @identifier = 'ConditionalAGExecution';" | out-null

    # Verify task completes
    $result = Invoke-Sqlcmd -ServerInstance . -Database tsqlscheduler -Query "select count(*) as ExecutionCount from scheduler.Task as t join scheduler.TaskExecution as te on te.TaskId = t.TaskId where t.Identifier = 'ConditionalAGExecution'"

    return $result.ExecutionCount
}