# tsqlScheduler

Create agent jobs from definitions stored in SQL tables.

Roadmap:
- Wrapper procs around msdb agent job procedures
- Schema to store definition of jobs (time, command, name)
- Framework to force executions to log into a schema that supports monitoring without using msdb
- AG Support - Create jobs on all potential hosts
- AG Support - Link a job to an AG and only execute the job if the replica is the primary
