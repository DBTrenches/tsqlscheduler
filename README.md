# tsqlScheduler

Create agent jobs from definitions stored in SQL tables. asd
## Installation
asdasd
Run the script src/Create Objects.sql in the target database.  This will create all necessary objects, dropping any that already exist.  The objects will all be created in the scheduler schema.

The script requires SQL 2016 SP1.

## Usage

Add tasks to the scheduler.Task table, and then run the procedure scheduler.CreateJobFromTask passing either the task Id or Identifier to create a SQL Agent job which will execute your task.

You can monitor executions via the scheduler.TaskExecution table.  Task configuration history is available in the scheduler.TaskHistory table, or by querying the scheduler.Task table with a temporal query.

## Tests

 
The tests are currently hardcoded to point at a database called tsqlscheduler on a local instance.  A successful run looks something like this:

![Pester Tests](/PesterTests.png?raw=true "Pester Test Results")
