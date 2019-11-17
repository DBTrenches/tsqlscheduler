Function Get-DatabaseTask 
{
  [cmdletbinding()]
  Param (
    [Parameter(Mandatory=$true)]
    [string] $Server,

    [Parameter(Mandatory=$true)]
    [string] $Database,

    [Parameter(Mandatory=$true)]
    [string] $TaskUid
  )

  $tasks = Get-DatabaseTasks -Database $Database -Server $Server -TaskUid $TaskUid
  
  if($tasks.Length -gt 0) {
    $tasks[0]
  }
}