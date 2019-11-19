Function Remove-DatabaseTask 
{
  [cmdletbinding()]
  Param (
    [Parameter(Mandatory=$true)]
    [string] $Server,

    [Parameter(Mandatory=$true)]
    [string] $Database,

    [Parameter(Mandatory=$true)]
    [string] $TaskUid
  )

  $deleteQuery = "
delete from scheduler.Task where TaskUid = '$TaskUid'
"

  Invoke-SqlCmd -ServerInstance $Server -Database $Database -Query $deleteQuery
}