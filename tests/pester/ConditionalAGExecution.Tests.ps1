. .\TestHelpers.ps1

Describe "Task.AvailabilityGroup" {
    It "should execute tasks scheduled on the primary replica" {
        CleanupTasksAndExecutions
        InsertTask -AvailabilityGroup "ALWAYS_PRIMARY"
        ExecuteTask  
        GetTaskExecutionCount | Should be 1
    }

    It "should not execute tasks scheduled on the secondary replica" {
        CleanupTasksAndExecutions
        InsertTask -AvailabilityGroup "NEVER_PRIMARY"
        ExecuteTask  
        GetTaskExecutionCount | Should be 0
    }

    It "should execute tasks when no AG is specified" {
        CleanupTasksAndExecutions
        InsertTask -AvailabilityGroup $null
        ExecuteTask  
        GetTaskExecutionCount | Should be 1
    }
}
