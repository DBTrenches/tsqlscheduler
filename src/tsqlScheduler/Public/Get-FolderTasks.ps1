Function Get-FolderTasks
{
  [cmdletbinding()]
  Param (
    [Parameter(Mandatory=$true)]
    [ValidateScript({ Test-Path -Path $PSItem })]
    [ValidateNotNullOrEmpty()]
    [string] $FolderPath
  )

  $rawTasks = Get-ChildItem -Path $FolderPath -Filter "*.task.json" | Get-Content -Raw | ConvertFrom-Json
  [Task[]]$rawTasks
}