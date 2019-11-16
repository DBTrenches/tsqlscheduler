using module .\Classes\tsqlscheduler.Job.psm1

. $PSScriptRoot/Install-SchedulerSolution
. $PSScriptRoot/Install-AutoUpsertJob
. $PSScriptRoot/Publish-TaskFromConfig
. $PSScriptRoot/Sync-SchedulerState

Function Test-Job
{
    [cmdletbinding()]
    Param (

    )
    
      $job = [Job]::new()
      $otherJob = [Job]::new()
      $job -eq $otherJob
      $otherJob.TaskUid = [Guid]::NewGuid()
      $job -eq $otherJob
      $job
      $otherJob
    
}