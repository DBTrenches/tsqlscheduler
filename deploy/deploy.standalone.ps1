Param(
    [string][parameter(mandatory=$true)] $server
    ,[string][parameter(mandatory=$true)] $database
    ,[string][parameter(mandatory=$true)] $notifyOperator
)

$query = "select oid = isnull(object_id('scheduler.Task'),-1)"
$validation = Invoke-Sqlcmd -ServerInstance $server -Database $database -Query $query

if($validation.oid -eq -1){
    Install-SchedulerSolution -Server $server -Database $database -agMode $false -verbose
}else{
    Write-Verbose "Local Scheduler already exists. Bumping Version..."
    Install-SchedulerSolution -Server $server -Database $database -agMode $false -versionBump $true -verbose
}

Install-AutoUpsertJob -Server $server -Database $database -TargetDatabase $database -NotifyOperator $notifyOperator
