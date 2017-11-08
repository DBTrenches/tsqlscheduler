# The AG Config File 

You can create your own AG config file by executing the below query on your AG.
	
```sql
declare 
	@agName sysname = 'AG1-sample',
	@agid uniqueidentifier;

select @agid = ag.group_id
from sys.availability_groups ag
where ag.[name] = @agName;

select 
    [Name]=ar.replica_server_name,
    [Role]=case @@servername
            when ar.replica_server_name then 'Primary'
            else 'Secondary'
        end
from sys.availability_replicas ar
where ar.group_id = @agid
for json path; 
```

Simply add `"IsSchedulerExcluded":true` for any replica which you do wish to deploy the HA Scheduler Solution. 

The AG config file should be saved in *this directory location*: `~/deploy/servers`. For our example, the AG is named `AG1-sample` and it's config file is [`AG1-sample.json`](/AG1-sample.json).
