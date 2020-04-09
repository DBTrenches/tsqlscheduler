Function Sync-FolderToDatabase
{
  [cmdletbinding(SupportsShouldProcess=$True)]
  Param (
    [Parameter(Mandatory=$true)]
    [ValidateScript({ Test-Path -Path $PSItem })]
    [ValidateNotNullOrEmpty()]
    [string] $FolderPath,

    [Parameter(Mandatory=$true)]
    [string] $Server,

    [Parameter(Mandatory=$true)]
    [string] $Database
  )

  $source = Get-FolderTasks -FolderPath $FolderPath
  Write-Verbose "$($source.Length) tasks in source"
  $destination = Get-DatabaseTasks -Server $Server -Database $Database
  Write-Verbose "$($destination.Length) tasks in destination"

  $comparison = Compare-TaskLists -Source $source -Destination $destination

  Write-Verbose "$($comparison.Add.Length) to Add, $($comparison.Update.Length) to Update, $($comparison.Remove.Length) to Remove, $($comparison.NoChange.Length) with no change."

  foreach($task in $comparison.Remove) {
    Remove-DatabaseTask -Server $Server -Database $Database -Task $task
  }
  foreach($task in $comparison.Add) {
    Set-DatabaseTask -Server $Server -Database $Database -Task $task
  }
  foreach($task in $comparison.Update) {
    Set-DatabaseTask -Server $Server -Database $Database -Task $task
  }

}