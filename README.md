##### [Installation](#installation) | [Notes & Requirements](#notes-and-requirements) | [Managing Tasks](#managing-tasks) | [Monitoring](#monitoring) | [How It Works](#how-it-works)

# tsqlScheduler

When running an Availability Group installation, you may wish to have the Server Agent execute Jobs against your highly available databases. However in the event of failover these Tasks will not exist by default on the replica. Additionally if you modify a Job on the primary replica, keeping parity on each secondary replica requires a separate action. This module automates parity of Server Agent Jobs across all replicas and makes Tasks executed by these Jobs Highly Available alongside any HA database.  

Create agent jobs from definitions stored in SQL tables.  Currently supports the following features:

- Schedule tasks to run on a schedule every day, or every `N` hours/minutes/seconds
- Automatically create a SQL Agent job from each task (stored in a Task table)
- Provide logging of task execution history (runtime, success/failure, error messages)
- Conditional execution of tasks based on database status - if the scheduler database is part of an availability group, tasks will only run when that node is the primary replica (the database is `read_write`)

This is intended as an administrative tool and as such requires and will schedule jobs to run with sysadmin / `sa` privileges.

## Installation

See the dedicated [installation instructions](deploy/Installation.md).

See also [Removing the Scheduler](deploy/Installation.md#uninstallation)

## Notes and Requirements

- SQL 2016+ is required (tested on 2016, 2017)
- [The server time must be UTC](#server-time)
- The replica must be configured as a [readable secondary][readable-secondary] 
- All requisite DBs must be created and added to the AG as necessary before installation.  
- Deployment scripts use integrated security.  Use of SQL Logins has not been tested but can be attempted but adding the appropriate [`Invoke-SqlCmd`][invoke-sqlcmd - BOL] flags in the [tsqlScheduler module](src/Modulers/tsqlScheduler/tsqlScheduler.psm1) and [deploying manually](deploy/README.md).
- Consider environment. Tasks in the HA scheduler with any dependencies outside the AG may not succeed after failover unless all dependencies are already available at the failover location.

## Managing Tasks

Jobs are managed via rows in the scheduler.Task table. Use the [`UpsertTask`](src/Procedures/UpsertTask.sql) proc to create, modify, or delete a task.  You can maintain a separate repository with configuration files and publish tasks [as described here](deploy/tasks/README.md).  

Usage of `UpsertTask` is demonstrated below.

```sql
declare 
	@jobName nvarchar(255) =  N'Utility-agDatabase-TaskName',
	@tsql nvarchar(max) =     N'',
	@operator nvarchar(128) = N'Test Operator'; 

exec scheduler.UpsertTask
    @action =            'INSERT', -- or 'UPDATE' or 'DELETE'
    @jobIdentifier =     @jobName, 
    @tsqlCommand =       @tsql, 
    @startTime =         '00:00', 
    @frequencyType =     'Minute', 
    @frequencyInterval = 1, 
    @notifyOperator =    @operator, 
    @isNotifyOnFailure = 0;
```

You can then either wait for the AutoUpsert job to run, or force creation of the agent job:

```sql
exec scheduler.CreateJobFromTask @identifier = '{taskuid guid of the job you just created}'
```

After deleting a task (`UpsertTask @action='DELETE, @taskuid=...`) in order forcibly delete the agent job, either wait for the AutoUpsert job or manually call the `RemoveJobFromTask` procedure. You are then free to delete the row from the task table.

#### Column reference

`FrequencyInterval` corresponds to the `x` for frequency types 2-4. It **must** be 0 if the frequency is set to daily.

The `StartTime` specified is either the time of day the job will run (if once per day), or the time of day the schedule starts (for any other frequency).

If `IsNotifyOnFailure` is true (1) then the specified operator will be notified by email every time the job fails.

## Monitoring

You can monitor executions via the `scheduler.TaskExecution` table.  

Task configuration history is available in the `scheduler.TaskHistory` table, or by querying the `scheduler.Task` table with a temporal query.

You can view currently running tasks by querying the **scheduler.CurrentlyExecutingTasks** view.  The SQL below will show all executing tasks as well as their last runtime & result.

```sql
select	te.StartDateTime
		,datediff(second,te.StartDateTime, getutcdate()) as DurationSeconds
		,t.Identifier
		,lastResult.StartDateTime as LastStartTime
		,datediff(second,lastResult.StartDateTime, lastResult.EndDateTime) as LastDurationSeconds
		,lastResult.IsError as LastIsError
from	scheduler.CurrentlyExecutingTasks as cet
join    scheduler.GetInstanceId() as id
on      cet.Instanceid = id.Id
join	scheduler.Task as t
on		t.TaskUid = cet.TaskUid
join	scheduler.TaskExecution as te
on		te.ExecutionId = cet.ExecutionId
outer apply (
	select top 1 *
	from scheduler.TaskExecution as teh
	where teh.TaskUid = t.TaskUid
	and teh.ExecutionId <> te.ExecutionId
	order by ExecutionId desc
) as lastResult
```

## How it works

The Task table holds one row for each task that should be executed in the context of that database.  When an agent job is created from this task a job is created as a wrapper around the `scheduler.ExecuteTask` stored procedure.  This procedure uses the metadata from the Task table to execute the TSQLCommand with `sp_executesql`.

Before the task is executed the Id of the instance, task, and execution are stored in the [`context_info`][context_info - BOL] object, which allows the task to be tracked via the [`scheduler.CurrentlyExecutingTasks`](crs/Views/CurrentlyExecutingTasks.sql) view.

The auto-upsert logic uses the temporal table field `SysStartTime` on the Task table, and the agent job's last modified date, to determine which jobs require modification.

### Server Time

**The server needs to be in the UTC time zone** for the solution to work correctly.  This is due to the comparison of [`sysjobs.date_modified`][sysjobs - BOL] to `Task.SysStartTime` in the `UpsertJobsForAllTasks` procedure.  `SysStartTime` is always recorded in UTC, whereas `date_modified` uses the server time.  If the server is not in UTC then there may be delays in job changes propagating to the agent job, or jobs may be recreated needlessly (depending on whether the server is ahead of or behind UTC).

### Code Style

- Keywords should be in lowercase
- Identifiers should not be escaped with brackets unless required (better to avoid using a reserved keyword)
- Use `<>` rather than `!=`
- Variables use `lowerCamelCase`
- Constants in `ALL_CAPS`
- Terminate statements with a semicolon

[sysjobs - BOL]: https://docs.microsoft.com/en-us/sql/relational-databases/system-tables/dbo-sysjobs-transact-sql
[context_info - BOL]: https://docs.microsoft.com/en-us/sql/t-sql/functions/context-info-transact-sql
[invoke-sqlcmd - BOL]: https://docs.microsoft.com/en-us/sql/powershell/invoke-sqlcmd-cmdlet
[readable-secondary]: https://docs.microsoft.com/en-us/sql/database-engine/availability-groups/windows/active-secondaries-readable-secondary-replicas-always-on-availability-groups