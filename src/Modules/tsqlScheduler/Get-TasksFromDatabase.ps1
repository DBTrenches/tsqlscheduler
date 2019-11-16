Function Get-TasksFromDatabase 
{
  [cmdletbinding()]
  Param (
      [string] $Server
      ,[string] $Database
      ,[string] $TaskUid
  )

  $getTasksQuery = "
select  
  TaskUid,
  Identifier,
  TSQLCommand,
  StartTime,
  Frequency,
  FrequencyInterval,
  NotifyOnFailureOperator,
  IsNotifyOnFailure,
  IsEnabled,
  IsDeleted,
  NotifyLevelEventlog
from scheduler.Task
"
  if($TaskUid) {
    $getTasksQuery += "where TaskUid = '$TaskUid'"
  }

  $rawTasks = @(Invoke-Sqlcmd -ServerInstance $Server -Database $Database -Query $getTasksQuery)
  $tasks = @()
  foreach($rawTask in $rawTasks) {
    $task = [Task]::new()
      $task.TaskUid = $rawTask.TaskUid
      $task.Identifier = $rawTask.Identifier
      $task.TSQLCommand = $rawTask.TSQLCommand
      $task.StartTime = $rawTask.StartTime
      $task.Frequency = $rawTask.Frequency
      $task.FrequencyInterval = $rawTask.FrequencyInterval
      $task.NotifyOnFailureOperator = $rawTask.NotifyOnFailureOperator
      $task.IsNotifyOnFailure = $rawTask.IsNotifyOnFailure
      $task.IsEnabled = $rawTask.IsEnabled
      $task.IsDeleted = $rawTask.IsDeleted
      $task.NotifyLevelEventlog = $rawTask.NotifyLevelEventlog
    $tasks += $task
  }

  $tasks
}