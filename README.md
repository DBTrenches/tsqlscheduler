# tsqlScheduler

Create agent jobs from definitions stored in SQL tables.  Currently supports the following features:

- Schedule tasks to run on a schedule every day, or every N hours/minutes/seconds
- Automatically create a SQL Agent job from each task (stored in a Task table)
- Provide logging of task execution history (runtime, success/failure, error messages)
- Conditional execution of tasks based on replica status - if an availability group is linked to a task that task will only run when that node is the primary replica

This is intended as an administrative tool and as such requires and will schedule jobs to run with sysadmin (sa) privileges.

## Installation

### Availability Group Mode

- Clone the repository and dot source the DeploymentFunctions.ps1 script file
- Deploy the solution in AG mode against a database in the AG
- Deploy the solution in standalone mode against every instance which can host the primary replica (not in an AG database)
- Deploy the AutoUpsert task on all nodes which can host the AG
  - The notify operator must exist on the instance or the job will not be created
- Deploy the UpdateReplicaStatus job against the AG solution

```powershell
. ./src/DeploymentFunctions.ps1

# Deploy once in AG mode
Install-SchedulerSolution -Server primaryNode -Database agDatabase -agMode $true

# Deploy once potential primary per-node in standalone mode (needed once per node only, not once per AG)
Install-SchedulerSolution -Server primaryNode -Database Utility -agMode $false
Install-SchedulerSolution -Server secondaryNode -Database Utility -agMode $false

# Create the job on every node that can host the primary
Install-AutoUpsertJob -Server primaryNode -Database Utility -TargetDatabase agDatabase -NotifyOperator "Test Operator"
Install-AutoUpsertJob -Server secondaryNode -Database Utility -TargetDatabase agDatabase -NotifyOperator "Test Operator"

# Create the job that keeps track of the replica status
Install-ReplicaStatusJob -Server primaryNode -Database agDatabase -AvailabilityGroup AGName -NotifyOperator "Test Operator"
```

If an instance hosts multiple availability groups, the Utility database would need to contain one AutoUpsert task for every AG.

If the Utility database on each instance was also going to be used to schedule instance tasks (rather than just the tasks in agDatabase) an additional pair of tasks would be required:

```powershell
Install-AutoUpsertJob -Server primaryNode -Database Utility -TargetDatabase Utility -NotifyOperator "Test Operator"
Install-AutoUpsertJob -Server secondaryNode -Database Utility -TargetDatabase Utility -NotifyOperator "Test Operator"
```

#### Auto-create jobs in AG deployments - walkthrough

The deployment above assumes we have a two node cluster (primaryNode, secondaryNode) which hosts an AG that is primary/secondary on the respectively named nodes, containing a database called agDatabase.

The scheduler solution is deployed 3 times, and two auto-upsert jobs are created.

agDatabase
- Contains the scheduler schema deployed in AG mode
- Contains no tasks by default
- Contains a stored procedure that creates an agent job on the current instance based on tasks in the task table

primaryNode, secondaryNode
- Contains the scheduler schema deployed in standalone mode
- Contains a single task (and linked agent job) which will periodically call the upsert procedure in agDatabase

Key here is that the two standalone deployments will both periodically call into agDatabase and invoke the upsert stored procedure, creating agent jobs for that AG on both nodes.  Note that this requires the AG to have readable secondaries.

### Standalone (Instance) Mode

- Clone the repository and dot source the DeploymentFunctions.ps1 script file
- Deploy the solution in standalone mode against the target instance
- Deploy the AutoUpsert task on the instance
  - The notify operator must exist on the instance or the job will not be created.

```powershell
. ./src/DeploymentFunctions.ps1

# Deploy in standalone mode
Install-SchedulerSolution -Server primaryNode -Database Utility -agMode $false
Install-AutoUpsertJob -Server primaryNode -Database Utility -TargetDatabase Utility -NotifyOperator "Test Operator"
```

### Notes

- Deployment scripts assume you will use integrated security.  If you need to use SQL Logins then you need to edit the DeployAllObjects.ps1 script.
- The solution will be deployed into the scheduler schema.
- The script requires SQL 2016 SP1.
- The objects can be removed with the RemoveAllObjects SQL script.  Note that this will remove the objects but not any SQL Agent jobs which have been created.

## Managing Tasks

### Creating a task

Add a task to the scheduler.Task table, using the following SQL as an template.

```sql
insert into scheduler.Task
( Identifier, TSQLCommand, StartTime, FrequencyType, FrequencyInterval, NotifyOnFailureOperator, IsNotifyOnFailure )
values
( 'TaskName', 'select @@servername', '00:00', 3, 10, 'Test Operator', 0 );
```

If you are deploying the task into an installation in AG mode you'll need to also specify the availability group name.

You can then either wait for the AutoUpsert job to run, or force creationg of the agent job:

```sql
exec scheduler.CreateJobFromTask @identifier = 'TaskName'
```

#### Column reference

Frequency Type
- 1 = Once per day
- 2 = Every x hours
- 3 = Every x minutes
- 4 = Every x seconds

Frequency interval corresponds to the x for frequency types 2-4, and should be 0 if the frequency is set to daily.

The start time specified is either the time of day the job will run (if once per day), or the time of day the schedule starts (for any other frequency).

If IsNotifyOnFailure is true (1) then the specified operator will be notified by email every time the job fails.

### Deleting a job/task

Set the IsDeleted flag to 1 on the task, and then either wait for the AutoUpsert job or manually call the RemoveJobFromTask procedure:

```sql
exec scheduler.RemoveJobFromTask @identifier = 'TaskName'
```

You are then free to delete the row from the task table.

## Monitoring

You can monitor executions via the scheduler.TaskExecution table.  

Task configuration history is available in the scheduler.TaskHistory table, or by querying the scheduler.Task table with a temporal query.

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
on		t.TaskId = cet.TaskId
join	scheduler.TaskExecution as te
on		te.ExecutionId = cet.ExecutionId
outer apply (
	select top 1 *
	from scheduler.TaskExecution as teh
	where teh.TaskId = t.TaskId
	and teh.ExecutionId <> te.ExecutionId
	order by ExecutionId desc
) as lastResult
```

## How it works

The Task table holds one row for each task that should be executed in the context of that database.  When an agent job is created from this task a job is created as a wrapper around the scheduler.ExecuteTask stored procedure.  This procedure uses the metadata from the Task table to execute the TSQLCommand with sp_executesql.

Before the task is executed the Id of the instance, task, and execution are stored in the context_info object, which allows the task to be tracked.

The auto-upsert logic uses the temporal table field (SysStartTime) on the Task table, and the agent job's last modified date, to determine which jobs require modification.

Any task set to deleted (IsDeleted = 1) will have its corresponding agent job deleted by the upsert job.

## Tracking Replica Role (AG Mode)

Rather than query the DMV on every call to ExecuteTask (as was the behaviour in 1.0), a job runs to periodically persist the current status of each node.  This table is then queried by ExecuteTask to see if the task should execute.  This was done to minimise blocking caused when many concurrent tasks query this DMV.

## Code Style

- Keywords should be in lowercase
- Identifiers should not be escaped with brackets unless required (better to avoid using a reserved keyword)
- Use <> rather than !=
- Variables use lowerCamelCase
- Constants in ALL_CAPS
- Terminate statements with a semicolon