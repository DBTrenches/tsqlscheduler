Function Set-FolderTask
{
  [cmdletbinding(SupportsShouldProcess=$True)]
  Param (
    [Parameter(Mandatory=$true)]
    [ValidateScript({ Test-Path -Path $PSItem })]
    [ValidateNotNullOrEmpty()]
    [string] $FolderPath,

    [Parameter(Mandatory=$true)]
    [Task] $Task
  )

  $Task | ConvertTo-Json | Set-Content -Path "$FolderPath\$($Task.TaskUid).task.json"
}