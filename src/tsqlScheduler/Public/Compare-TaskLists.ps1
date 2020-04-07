Function Compare-TaskLists {
  [cmdletbinding()]
  Param (
    [Parameter(Mandatory = $true)]
    [AllowNull()]
    [Task[]] $SourceTasks,

    [Parameter(Mandatory = $true)]
    [AllowNull()]
    [Task[]] $DestinationTasks
  )

  if($null -eq $SourceTasks) {
    $SourceTasks = @()
  }

  if($null -eq $DestinationTasks) {
    $DestinationTasks = @()
  }

  # Build a destination of source/destination tasks, keyed on the TaskUid
  $source = @{ }
  $SourceTasks | ForEach-Object { $source[$_.TaskUid] = $_ }
  $dest = @{ }
  $DestinationTasks | ForEach-Object { $dest[$_.TaskUid] = $_ } 

  # Return object
  $comparison = [pscustomobject]@{
    Add      = @()
    Update   = @()
    NoChange = @()
    Remove   = @()
  }

  # Iterate the source and determine add/update/no change
  foreach ($taskKvp in $source.GetEnumerator()) {
    $task = $taskKvp.Value
    if (-not $dest.ContainsKey($task.TaskUid)) {
      $comparison.Add += $task
    }
    else {
      if ($task -eq $dest[$task.TaskUid]) {
        $comparison.NoChange += $task
      }
      else {
        $comparison.Update += $task
      }
    }
  }

  # Iterate the destination and determine remove
  foreach ($taskKvp in $dest.GetEnumerator()) {
    $task = $taskKvp.Value
    if (-not $source.ContainsKey($task.TaskUid)) {
      $comparison.Remove += $task
    }
  }

  $comparison
}