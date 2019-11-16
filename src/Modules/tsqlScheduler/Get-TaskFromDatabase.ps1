Function Get-TaskFromDatabase 
{
  [cmdletbinding()]
  Param (
      [string] $Server
      ,[string] $Database
      ,[string] $TaskUid
  )
  $tasks = Get-TasksFromDatabase -Database $Database -Server $Server -TaskUid $TaskUid
  
  if($tasks.Length -gt 0) {
    $tasks[0]
  }
}