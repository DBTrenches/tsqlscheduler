Function Remove-DatabaseTask 
{
  [cmdletbinding()]
  Param (
    [Parameter(Mandatory=$true)]
    [string] $Server,

    [Parameter(Mandatory=$true)]
    [string] $Database,

    [Parameter(Mandatory=$true)]
    [Task] $Task
  )

  $deleteQuery = "
delete from scheduler.Task where TaskUid = '$($Task.TaskUid)'
"

  Invoke-SqlCmd -ServerInstance $Server -Database $Database -Query $deleteQuery
}