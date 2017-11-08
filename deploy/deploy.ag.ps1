Param(
    [string][parameter(mandatory=$true)] $agName
    ,[parameter(mandatory=$true)] $replicas
    ,[string][parameter(mandatory=$true)] $server
    ,[string][parameter(mandatory=$true)] $database
    ,[string][parameter(mandatory=$true)] $agDatabase
    ,[string][parameter(mandatory=$true)] $notifyOperator
)

Install-SchedulerSolution -Server $server -Database $agDatabase -agMode $true -AvailabilityGroup $agName

foreach($replica in $replicas){
    $serverName = $replica.Name

    $query = "select oid = isnull(object_id('scheduler.Task'),-1)"
    $validation = Invoke-Sqlcmd -ServerInstance $serverName -Database $database -Query $query

    if($validation.oid -eq -1){
        Install-SchedulerSolution -server $serverName -database $database -agMode $false
    }
    Install-AutoUpsertJob -server $serverName -database $database -TargetDatabase $agDatabase -notifyOperator $notifyOperator
}

Install-ReplicaStatusJob -Server $server -Database $agDatabase -NotifyOperator $notifyOperator
