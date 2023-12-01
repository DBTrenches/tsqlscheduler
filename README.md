##### [Installation](#installation) | [Notes & Requirements](#notes-and-requirements) | [Managing Tasks](#managing-tasks) | [Monitoring](#monitoring) | [Powershell Module Reference](#powershell-module-reference) | [How It Works](#how-it-works)

# tsqlScheduler

When running an Availability Group installation, you may wish to have the Server Agent execute Jobs against your highly available databases. However in the event of failover these Tasks will not exist by default on the replica. Additionally if you modify a Job on the primary replica, keeping parity on each secondary replica requires a separate action. This module automates parity of Server Agent Jobs across all replicas and makes Tasks executed by these Jobs Highly Available alongside any HA database.

Create agent jobs from definitions stored in SQL tables. Currently supports the following features:

- Schedule tasks to run on a schedule every day, or every `N` hours/minutes/seconds
- Automatically create a SQL Agent job from each task (stored in a Task table)
- Provide logging of task execution history (runtime, success/failure, error messages)
- Conditional execution of tasks based on database status - if the scheduler database is part of an availability group, tasks will only run when that node is the primary replica (the database is `read_write`)

This is intended as an administrative tool and as such requires and will schedule jobs to run with sysadmin / `sa` privileges.

## Installation

See the dedicated [installation instructions](docs/Installation.md).

See also [Removing the Scheduler](docs/Installation.md#uninstallation)

## Notes and Requirements

- SQL 2016+ is required (tested on 2016, 2017)
- [The server time must be UTC](#server-time)
- Replicas that host jobs must be configured as a [readable secondary][readable-secondary]
- All requisite DBs must be created and added to the AG before installation.
- Deployment scripts use integrated security. Use of SQL Logins has not been tested but can be attempted but adding the appropriate [`Invoke-SqlCmd`][Invoke-SqlCmd - bol] flags in the [tsqlScheduler module](src/tsqlScheduler/tsqlScheduler.psm1).
- Consider environment. Tasks in the HA scheduler with any dependencies outside the AG may not succeed after failover unless all dependencies are already available on the new primary.

## Managing Tasks

Jobs are managed via rows in the scheduler.Task table. You can maintain a separate repository with configuration files and keep it in sync with the various Sync cmdlets (`Sync-FolderToDatabase`, etc.).

Inserting a task can be done with SQL:

```sql
insert into scheduler.Task
(
  Identifier
  ,TSQLCommand
  ,StartTime
  ,Frequency
  ,FrequencyInterval
  ,NotifyOnFailureOperator
)
values
(
  'I will run once an hour'
  ,'select 1 as AndNotDoMuch'
  ,'00:00:00'
  ,'Hour'
  ,1
  ,'Test Operator'
)
```

You can then either wait for the AutoUpsert job to run, or force creation of the agent job:

```sql
exec scheduler.CreateJobFromTask @TaskUid = '{TaskUid guid of the job you just created}'
```

After marking a task as deleted, in order forcibly delete the agent job you can either wait for the AutoUpsert job or manually call the `scheduler.RemoveJobFromTask` procedure. You are then free to delete the row from the task table.

### Column reference

`Frequency` is one of `Day`,`Hour`,`Minute`, or `Second`.

`FrequencyInterval` corresponds to the `x` for frequency types Hour/Minute/Second. It **must** be 0 if the frequency is set to daily.

The `StartTime` specified is either the time of day the job will run (if once per day), or the time of day the schedule starts (for any other frequency).

If `IsNotifyOnFailure` is true (1) then the specified operator (`NotifyOnFailureOperator`) will be notified by email every time the job fails.

`NotifyLevelEventlog` controls which job completions write to the Windows event log, it can be one of `Never`, `OnFailure` (default), `OnSuccess`, or `Always`.

## Monitoring

You can monitor executions via the `scheduler.TaskExecution` table. This table is partitioned by default on a scheme which uses month of year (execution date) as the partition key.  Every time a task is executed a row is inserted in this table.

Task configuration history is available in the `scheduler.TaskHistory` table, or by querying the `scheduler.Task` table with a temporal query.

You can view currently running tasks by querying the **scheduler.CurrentlyExecutingTasks** view. The SQL below will show all executing tasks as well as their last runtime & result.

```sql
select  te.StartDateTime
    ,datediff(second,te.StartDateTime, getutcdate()) as DurationSeconds
    ,t.Identifier
    ,lastResult.StartDateTime as LastStartTime
    ,datediff(second,lastResult.StartDateTime, lastResult.EndDateTime) as LastDurationSeconds
    ,lastResult.IsError as LastIsError
from  scheduler.CurrentlyExecutingTasks as cet
join    scheduler.GetInstanceId() as id
on      cet.Instanceid = id.Id
join  scheduler.Task as t
on    t.TaskUid = cet.TaskUid
join  scheduler.TaskExecution as te
on    te.ExecutionId = cet.ExecutionId
outer apply (
  select top 1 *
  from scheduler.TaskExecution as teh
  where teh.TaskUid = t.TaskUid
  and teh.ExecutionId <> te.ExecutionId
  order by ExecutionId desc
) as lastResult
```

You can query MSDB to find all jobs linked to the current instance (database) with the view `scheduler.AgentJobsForCurrentInstance`.

## How it works

The Task table holds one row for each task that should be executed in the context of that database. When an agent job is created from this task a job is created as a wrapper around the `scheduler.ExecuteTask` stored procedure. This procedure uses the metadata from the Task table to execute the TSQLCommand with `sp_executesql`. The InstanceId and TaskId are stored in the job description, encoded with JSON.

Before the task is executed the Id of the instance, task, and execution are stored in the [`context_info`][context_info - bol] object, which allows the task to be tracked via the [`scheduler.CurrentlyExecutingTasks`](src/tsqlScheduler/SQL/Views/CurrentlyExecutingTasks.sql) view.

The auto-upsert logic uses the temporal table field `SysStartTime` on the Task table, and the agent job's last modified date, to determine which jobs require modification.

### Server Time

**The server needs to be in the UTC time zone** for the solution to work correctly. This is due to the comparison of [`sysjobs.date_modified`][sysjobs - bol] to `Task.SysStartTime` in the `UpsertJobsForAllTasks` procedure. `SysStartTime` is always recorded in UTC, whereas `date_modified` uses the server time. If the server is not in UTC then there may be delays in job changes propagating to the agent job, or jobs may be recreated needlessly (depending on whether the server is ahead of or behind UTC).

## PowerShell Module Reference

In addition to installation, the tsqlScheduler module supports task management. All cmdlets that make changes support the `-WhatIf` switch.

### Database task management

These cmdlets support get/set/remove operations on tasks stored in a database.

- `Get-DatabaseTasks`
- `Get-DatabaseTask`
- `Set-DatabaseTask`
- `Remove-DatabaseTask`

### Folder task management

These cmdlets support get/set/remove operations on tasks stored in the file system (they assume each task is saved as as {TaskUid}.task.json).

- `Get-FolderTasks`
- `Get-FolderTask`
- `Set-FolderTask`
- `Remove-FolderTask`

### Comparison

This cmdlet compares two arrays of `Task` objects, returning a result object that contains Add, Update, NoChange, and Remove arrays.

- `Compare-TaskLists`

### Sync

These cmdlets sync tasks between the filesystem and the database (in any combination). They all support the `-WhatIf` switch.

- `Sync-DatabaseToDatabase`
- `Sync-DatabaseToFolder`
- `Sync-FolderToDatabase`
- `Sync-FolderToFolder`

### Validation

This cmdlet will validate all task files (`*.task.json`) are valid `Task` objects. Returns `$true` if there are no issues. Useful in a CI build to prevent any invalid tasks being checked in.

- `Test-FolderTasks`

### Example sync code

Assume we want to take a copy of our database tasks and store them in a git repo on disk:

```powershell
$common = @{ Database = "SchedulerDB"; Server = "ProdServer" }
$gitFolder = "c:\src\DatabaseTasks\ProdServer"

Sync-DatabaseToFolder @common -FolderPath $gitFolder
```

Then perhaps we make some changes to a task to run it once every 6 hours, instead of once every day:

```powershell
$taskUid = "E1DF0D10-1160-4878-AD3D-C627670B167E"

# Get the task from the folder
$task = Get-FolderTask -FolderPath $gitFolder -TaskUid $taskUid

# Update the properties (note we could have edited the .json file directly too)
$task.Frequency = "Hour"
$task.FrequencyInterval = 6

# And save it back to the folder
Set-FolderTask -FolderPath $gitFolder -Task $task
```

And then we'll want to sync it back to the database - checking the impact first:

```powershell
Sync-FolderToDatabase @common -FolderPath $gitFolder -WhatIf

# And then do it for real - we use Verbose to see what is happening
Sync-FolderToDatabase @common -FolderPath $gitFolder -Verbose
```

## Misc

### Who wants to retain forever?

Thanks to the nifty `truncate partition` feature, you can efficienctly remove old `TaskExecution` records without the fun of dynamic partition management.

The procedure `scheduler.TaskExecutionRotate` is deployed with the schema, and by default will truncate all partitions older than 3 months.  This job is not scheduled by default, but you could add a daily job with the following:

```sql
insert into scheduler.Task
(
  Identifier
  ,TSQLCommand
  ,StartTime
  ,Frequency
  ,FrequencyInterval
  ,NotifyOnFailureOperator
)
values
(
  'SomeDB-Scheduler-CleanTaskExecution'
  ,'exec SomeDB.scheduler.TaskExecutionRotate'
  ,'00:00:00'
  ,'Day'
  ,0
  ,'SomeDB-Admin'
)
```

You can keep data longer than 12 months, though you'll end up with multiple years in each partition (as the partition schema is based on _month of year_).

### Code Style - SQL

- Keywords should be in lowercase
- Identifiers should not be escaped with brackets unless required (better to avoid using a reserved keyword)
- Use `<>` rather than `!=`
- Variables use `lowerCamelCase`
- Constants in `ALL_CAPS`
- Terminate statements with a semicolon

### Source Layout

- `\src`
  - `\Scripts` - Utility SQL scripts
  - `\tsqlScheduler` - Root of the PowerShell module
    - `\Classes` - PowerShell classes used by the module
    - `\Public` - PowerShell functions exported by the module
    - `\SQL` - SQL schema creation scripts

### Thanks

This module wouldn't exist without the exceptional folks who are either directly responsible for ideas/code, or who have had to suffer as guinea pigs.

Special thanks to [@petervandivier], [@morshedk], [@josemaurette] and [@andrewalumkal].


[sysjobs - bol]: https://docs.microsoft.com/en-us/sql/relational-databases/system-tables/dbo-sysjobs-transact-sql
[context_info - bol]: https://docs.microsoft.com/en-us/sql/t-sql/functions/context-info-transact-sql
[Invoke-SqlCmd - bol]: https://docs.microsoft.com/en-us/sql/powershell/invoke-sqlcmd-cmdlet
[readable-secondary]: https://docs.microsoft.com/en-us/sql/database-engine/availability-groups/windows/active-secondaries-readable-secondary-replicas-always-on-availability-groups

[@petervandivier]: https://github.com/petervandivier
[@morshedk]: https://github.com/morshedk
[@josemaurette]: https://github.com/josemaurette
[@andrewalumkal]: https://github.com/andrewalumkal
