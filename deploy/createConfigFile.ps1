Write-Host "`nConfig file for [$agName] not found in deploy/servers. Attempting to auto-generate now."
$global:server=Read-Host "Enter the name of the primary replica for [$agName]."
$notifyOperator=Read-Host "Enter the name of the operator"
$database=Read-Host "Enter the name of the database to host the local scheduler"
$agDatabase=Read-Host "Enter the name of the HA database to host the scheduler in the AG"

$sqlParseAG="declare 
	@agName sysname = '$agName',
	@agid uniqueidentifier;

select @agid = ag.group_id
from sys.availability_groups ag
where ag.[name] = @agName;

select 
    AvailablitiyGroupName=@agName,
    NotifyOperator='$notifyOperator',
    LocalDB='$database',
    HADB='$agDatabase',
    Replicas=(select 
                    [Name]=ar.replica_server_name,
                    [Role]=case @@servername
                            when ar.replica_server_name then 'Primary'
                            else 'Secondary'
                        end
                from sys.availability_replicas ar
                where ar.group_id = @agid
                for json path)
for json path;"

$outFile = "..\deploy\servers\$agName.json"

Invoke-Sqlcmd -ServerInstance $server -Database master -Query $sqlParseAG | Out-File $outFile -Encoding ascii -Width 9001
#trim off headers from sql query
(Get-Content $outfile | Select-Object -Skip 3) | Set-Content $outfile

# TODO?
# open new config file in default text editor after creation...
# ...and/or suggest prettification to user
