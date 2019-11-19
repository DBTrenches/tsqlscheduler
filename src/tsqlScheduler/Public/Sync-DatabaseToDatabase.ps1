Function Sync-DatabaseToDatabase
{
  [cmdletbinding(SupportsShouldProcess=$True)]
  Param (
    [Parameter(Mandatory=$true)]
    [string] $Server,

    [Parameter(Mandatory=$true)]
    [string] $Database,

    [Parameter(Mandatory=$true)]
    [string] $DestinationServer,

    [Parameter(Mandatory=$true)]
    [string] $DestinationDatabase
  )

  $source = Get-DatabaseTasks -Server $Server -Database $Database
  Write-Verbose "$($source.Length) tasks in source"
  $destination = Get-DatabaseTasks -Server $DestinationServer -Database $DestinationDatabase
  Write-Verbose "$($destination.Length) tasks in destination"

  $comparison = Compare-TaskLists -Source $source -Destination $destination

  Write-Verbose "$($comparison.Add.Length) to Add, $($comparison.Update.Length) to Update, $($comparison.Remove.Length) to Remove, $($comparison.NoChange.Length) with no change."

  foreach($task in $comparison.Add) {
    Set-DatabaseTask -Server $DestinationServer -Database $DestinationDatabase -Task $task
  }
  foreach($task in $comparison.Update) {
    Set-DatabaseTask -Server $DestinationServer -Database $DestinationDatabase -Task $task
  }
  foreach($task in $comparison.Remove) {
    Remove-DatabaseTask -Server $DestinationServer -Database $DestinationDatabase -Task $task
  }
}