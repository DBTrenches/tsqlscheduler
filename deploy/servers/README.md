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

## Oops! I accidentally deployed to a replica I didn't want to deploy to!

Because the config file can be auto-generated, it's actually pretty easy to deploy the scheduler to a replica you had previously excluded by using the `"IsSchedulerExcluded":true` flag if you lose the config file. 

To remove scheduler objects from this replica, set the `...-UpsertJobsForAllTasks` job in the Local DB deleted  _for this AG_ and then execute the following in your HADB to get the script for actual job deletion. 

```sql
select 
	cmd='exec msdb..sp_delete_job @job_name='''+t.Identifier+''', @delete_unused_schedule=1;'
from scheduler.Task t 
join msdb..sysjobs j on j.name = t.Identifier;
```
  