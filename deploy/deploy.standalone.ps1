Param(
    [string][parameter(mandatory=$true)] $server
    ,[string][parameter(mandatory=$true)] $database
    ,[string][parameter(mandatory=$true)] $notifyOperator
)

Install-SchedulerSolution -Server $server -Database $database -agMode $false
Install-AutoUpsertJob -Server $server -Database $database -TargetDatabase $database -NotifyOperator $notifyOperator
