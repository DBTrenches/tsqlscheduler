Function Sync-DatabaseToFolder
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

  $source = Get-DatabaseTasks -Server $Server -Database $Database
  Write-Verbose "$($source.Length) tasks in source"
  $destination = Get-FolderTasks -FolderPath $FolderPath
  Write-Verbose "$($destination.Length) tasks in destination"

  $comparison = Compare-TaskLists -Source $source -Destination $destination

  Write-Verbose "$($comparison.Add.Length) to Add, $($comparison.Update.Length) to Update, $($comparison.Remove.Length) to Remove, $($comparison.NoChange.Length) with no change."

  foreach($task in $comparison.Add) {
    Set-FolderTask -FolderPath $FolderPath $task
  }
  foreach($task in $comparison.Update) {
    Set-FolderTask -FolderPath $FolderPath $task
  }
  foreach($task in $comparison.Remove) {
    Remove-FolderTask -FolderPath $FolderPath $task
  }
}