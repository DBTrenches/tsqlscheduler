. .\TestHelpers.ps1

Describe "Task.IsEnabled" {
    It "should execute enabled tasks" {
        CleanupTasksAndExecutions
        InsertTask -IsEnabled $true
        ExecuteTask  
        GetTaskExecutionCount | Should be 1
    }

    It "should not execute disabled tasks" {
        CleanupTasksAndExecutions
        InsertTask -IsEnabled $false
        ExecuteTask  
        GetTaskExecutionCount | Should be 0
    }
}
