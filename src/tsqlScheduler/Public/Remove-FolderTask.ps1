Function Remove-FolderTask
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

  Remove-Item -Path $FolderPath -Include "$($TaskUid.ToString()).task.json"
}