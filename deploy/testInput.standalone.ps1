param(
    [string][parameter(mandatory=$true)] $server
    ,[string][parameter(mandatory=$true)] $database
    ,[string][parameter(mandatory=$true)] $notifyOperator
)

$query = "
select server_major_version=serverproperty('ProductMajorVersion'),
       db_id=isnull(db_id('$database'),-1),
       notify_operator_id=isnull(
            (select notify_operator_id=o.id
             from msdb.dbo.sysoperators o
             where o.name = '$notifyOperator'),-1);"

$validation = Invoke-Sqlcmd -ServerInstance $server -Database master -Query $query

$message = ""
$errorCount = 0

if($validation.server_major_version -lt 13){
    $message += "Server Version must be SQL Server 2016 or greater. "
    $errorCount += 1
}

if($validation.db_id -eq -1){
    $message += "Selected database [$database] was not discovered at server [$server]. "
    $errorCount += 1
}

if($validation.notify_operator_id -eq -1){
    $message += "Selected operator [$notifyOperator] was not discovered at server [$server]. "
    $errorCount += 1
}

if($errorCount -gt 0){throw $message}

$global:globalErrorCount += $errorCount
