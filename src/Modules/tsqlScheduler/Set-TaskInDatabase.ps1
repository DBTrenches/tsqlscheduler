Function Set-TaskInDatabase
{
  [cmdletbinding()]
  Param (
    [Parameter(Mandatory=$true)]
    [string] $Server,

    [Parameter(Mandatory=$true)]
    [string] $Database,

    [Parameter(Mandatory=$true)]
    [Task] $Task
  )

  Write-Warning "Needs implementation"
}