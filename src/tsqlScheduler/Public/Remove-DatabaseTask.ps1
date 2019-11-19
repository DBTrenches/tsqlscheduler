Function Remove-DatabaseTask {
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


    $deleteQuery = "
delete from scheduler.Task where TaskUid = '$($Task.TaskUid)'
"

    Invoke-SqlCmd -ServerInstance $Server -Database $Database -Query $deleteQuery
  }
}