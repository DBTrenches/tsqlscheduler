param(
    [string][parameter(mandatory=$true)] $agName
    ,[parameter(mandatory=$true)] $replicas
    ,[string][parameter(mandatory=$true)] $agDatabase
    ,[string][parameter(mandatory=$true)] $notifyOperator
)

$query = "
select server_major_version=serverproperty('ProductMajorVersion'),
       db_id=isnull(db_id('$database'),-1),
       notify_operator_id=isnull(
            (select notify_operator_id=o.id
             from msdb.dbo.sysoperators o
             where o.name = '$notifyOperator'),-1);"

foreach($replica in $replicas){
    $serverName = $replica.Name
    ..\deploy\testInput.standalone -server $serverName -database $agDatabase -notifyOperator $notifyOperator
}

# TODO?
# Itemize error state foreach() & return
