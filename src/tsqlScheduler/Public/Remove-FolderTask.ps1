Function Remove-FolderTask
{
  [cmdletbinding()]
  Param (
    [Parameter(Mandatory=$true)]
    [ValidateScript({ Test-Path -Path $PSItem })]
    [ValidateNotNullOrEmpty()]
    [string] $FolderPath,

    [Parameter(Mandatory=$true)]
    [Task] $Task
  )

  Remove-Item -Path $FolderPath -Include "$($Task.TaskUid).task.json"
}