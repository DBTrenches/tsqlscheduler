# tsqlScheduler

Create agent jobs from definitions stored in SQL tables.  Currently supports the following features:

- Schedule tasks to run on a schedule every day, or every N hours/minutes/seconds
- Automatically create a SQL Agent job from each task
- Provide logging of task execution history (runtime, success/failure, error messages)
- Conditional execution of tasks based on replica status - if an availability group is linked to a task that task will only run when that node is the primary replica

This is intended as an administrative tool and as such requires and will schedule jobs to run with sysadmin (sa) privileges.

## Installation

### Availability Group Mode

- Clone the repository and dot source the DeploymentFunctions.ps1 script file
- Deploy the solution in AG mode against the AG database
- Deploy the solution in standalone mode against every instance which can host the primary replica
- Deploy the AutoUpsert task on all nodes which can host the AG.  
  - The notify operator must exist on the instance or the job will not be created.

```powershell
. ./src/DeploymentFunctions.ps1

# Deploy once in AG mode
Deploy-SchedulerSolution -Server primaryNode -Database agDatabase -agMode $true

# Deploy once potential primary per-node in standalone mode (needed once per node only, not once per AG)
Deploy-SchedulerSolution -Server primaryNode -Database Utility -agMode $false
Deploy-SchedulerSolution -Server secondaryNode -Database Utility -agMode $false

# Create the job on every node that can host the primary
Deploy-AutoUpsertJob -Server secondaryNode -Database Utility -TargetDatabase agDatabase -NotifyOperator "Test Operator"
Deploy-AutoUpsertJob -Server secondaryNode -Database Utility -TargetDatabase agDatabase -NotifyOperator "Test Operator"
```

In the example above we have a two-node availability group (primaryNode and secondaryNode).  They both have a non-AG database 'Utility' which hosts the standalone scheduler schema, as well as an AG specific scheduler schema that lives in an AG database (agDatabase).

The utility databases hold the jobs that run on every instance, and ensure that all the jobs in the AG scheduler schema exist on all relevant nodes.

### Standalone (Instance) Mode

- Clone the repository and dot source the DeploymentFunctions.ps1 script file
- Deploy the solution in standalone mode against the target instance
- Deploy the AutoUpsert task on the instance
  - The notify operator must exist on the instance or the job will not be created.

```powershell
. ./src/DeploymentFunctions.ps1

# Deploy in standalone mode
Deploy-SchedulerSolution -Server primaryNode -Database Utility -agMode $false
Deploy-AutoUpsertJob -Server primaryNode -Database Utility -TargetDatabase Utility -NotifyOperator "Test Operator"
```

### Notes

- Deployment scripts assume you will use integrated security.  If you need to use SQL Logins then you need to edit the DeployAllObjects.ps1 script.
- The solution will be deployed into the scheduler schema.
- The script requires SQL 2016 SP1.
- The objects can be removed with the RemoveAllObjects SQL script.  Note that this will remove the objects but not any SQL Agent jobs which have been created.

## Usage

Add tasks to the scheduler.Task table, and then run the procedure scheduler.CreateJobFromTask passing either the task Id or Identifier to create a SQL Agent job which will execute your task.  If you make updates to the task definition which change the schedule you should specify @overwriteExisting = 1 to recreate the schedule.  If you have deployed the AutoUpsertJob then every 10 minutes any new/modified tasks will automatically have their jobs upserted.

You can monitor executions via the scheduler.TaskExecution table.  Task configuration history is available in the scheduler.TaskHistory table, or by querying the scheduler.Task table with a temporal query.

If you set a task to deleted (IsDelete = 1) the process will also remove the agent job associated with that task.

## How it works

The Task table holds one row for each task that should be executed in the context of that database.  When an agent job is created from this task a job is created as a wrapper around the schedule.ExecuteTask stored procedure.  This procedure uses the metadata from the Task table to ultimately execute the TSQLCommand with sp_executesql.

The auto-upsert logic  uses the temporal table field on the Task table and the agent job's last modified date to determine which jobs require modification.

Any task set to deleted (IsDeleted = 1) will have its corresponding agent job deleted by the upsert job.

## Code Style

- Keywords should be in lowercase
- Identifiers should not be escaped with brackets unless required (better to avoid using a reserved keyword)
- Use <> rather than !=
- Variables use lowerCamelCase
- Constants in ALL_CAPS
- Terminate statements with a semicolon