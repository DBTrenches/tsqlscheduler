using module .\Classes\tsqlscheduler.Task.psm1

. $PSScriptRoot/Install-SchedulerSolution
. $PSScriptRoot/Install-AutoUpsertJob
. $PSScriptRoot/Sync-SchedulerState
. $PSScriptRoot/Get-TasksFromDatabase
. $PSScriptRoot/Get-TaskFromDatabase
. $PSScriptRoot/Set-TaskInDatabase
