Function Set-DatabaseTask {
  [cmdletbinding(SupportsShouldProcess = $True)]
  Param (
    [Parameter(Mandatory = $true)]
    [string] $Server,

    [Parameter(Mandatory = $true)]
    [string] $Database,

    [Parameter(Mandatory = $true)]
    [Task] $Task
  )
  if ($PSCmdlet.ShouldProcess("Task $($Task.TaskUid) in $Database on $Server")) {

    $mergeQuery = "
merge into scheduler.Task as target
using (
  values (
  '$($Task.TaskUid)'
  ,'$($Task.Identifier)'
  ,'$($Task.TSQLCommand)'
  ,'$($Task.StartTime)'
  ,'$($Task.Frequency)'
  ,$($Task.FrequencyInterval)
  ,'$($Task.NotifyOnFailureOperator)'
  ,$([int]$Task.IsNotifyOnFailure)
  ,$([int]$Task.IsEnabled)
  ,$([int]$Task.IsDeleted)
  ,'$($Task.NotifyLevelEventLog)'
  )
) as source (
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
)
on source.TaskUid = target.TaskUid
when not matched then insert (
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
) values (
  source.TaskUid,
  source.Identifier,
  source.TSQLCommand,
  source.StartTime,
  source.Frequency,
  source.FrequencyInterval,
  source.NotifyOnFailureOperator,
  source.IsNotifyOnFailure,
  source.IsEnabled,
  source.IsDeleted,
  source.NotifyLevelEventlog
)
when matched then update
  set TaskUid = source.TaskUid,
    Identifier = source.Identifier,
    TSQLCommand = source.TSQLCommand,
    StartTime = source.StartTime,
    Frequency = source.Frequency,
    FrequencyInterval = source.FrequencyInterval,
    NotifyOnFailureOperator = source.NotifyOnFailureOperator,
    IsNotifyOnFailure = source.IsNotifyOnFailure,
    IsEnabled = source.IsEnabled,
    IsDeleted = source.IsDeleted,
    NotifyLevelEventlog = source.NotifyLevelEventLog
;
"

    Invoke-SqlCmd -ServerInstance $Server -Database $Database -Query $mergeQuery
  }
}