Function Get-FolderTask
{
  [cmdletbinding()]
  Param (
    [Parameter(Mandatory=$true)]
    [ValidateScript({ Test-Path -Path $PSItem })]
    [ValidateNotNullOrEmpty()]
    [string] $FolderPath,

    [Parameter(Mandatory=$true)]
    [Guid] $TaskUid
  )

  $rawTask = Get-ChildItem -Path $FolderPath -Filter "$($TaskUid.ToString()).task.json" | Get-Content -Raw | ConvertFrom-Json
  [Task]$rawTask
}