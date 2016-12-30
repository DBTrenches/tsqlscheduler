# tsqlScheduler

Create agent jobs from definitions stored in SQL tables.  Currently supports the following features:

- Schedule tasks to run on a schedule every day, or every N hours/minutes/seconds
- Automatically create a SQL Agent job from each task
- Provide logging of task execution history (runtime, success/failure, error messages)
- Conditional execution of tasks based on replica status - if an availability group is linked to a task that task will only run when that node is the primary replica

This is intended as an administrative tool and as such requires and will schedule jobs to run with sysadmin (sa) privileges.

## Installation

Run the script src/Create Objects.sql in the target database.  This will create all necessary objects, dropping any that already exist.  The objects will all be created in the scheduler schema.

The script requires SQL 2016 SP1.

## Usage

Add tasks to the scheduler.Task table, and then run the procedure scheduler.CreateJobFromTask passing either the task Id or Identifier to create a SQL Agent job which will execute your task.  If you make updates to the task definition which change the schedule you should specify @overwriteExisting = 1 to recreate the schedule.

You can monitor executions via the scheduler.TaskExecution table.  Task configuration history is available in the scheduler.TaskHistory table, or by querying the scheduler.Task table with a temporal query.

## How it works

The Task table holds one row for each task that should be executed in the context of that database.  When an agent job is created from this task a job is created as a wrapper around the schedule.ExecuteTask stored procedure.  This procedure uses the metadata from the Task table to ultimately execute the TSQLCommand with sp_executesql.

## Tests
 
The tests are currently hardcoded to point at a database called tsqlscheduler on a local instance.  A successful run looks something like this:

![Pester Tests](/PesterTests.png?raw=true "Pester Test Results")
