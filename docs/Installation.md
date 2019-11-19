Jump To [Uninstallation](#uninstallation)

# Deployment

Deploying to an AG follows the below footprint. 

![](./img/AG1-sample-deployment.png)

Examples herein assume we have a two node cluster (`primaryNode`, `secondaryNode`) which hosts an AG that is primary/secondary on the respectively named nodes, containing a database called `agDatabase`.

For a two-replica AG, the scheduler solution is deployed 3 times (number of replicas plus 1), and two auto-upsert jobs are created.

##### `agDatabase`
- Contains the scheduler schema
- Contains no tasks by default
- Contains a stored procedure that creates an agent job on the current instance based on tasks in the task table

##### `primaryNode`, `secondaryNode`
- Contains the scheduler schema
- Contains a single task (and linked agent job) which will periodically call the upsert procedure in `agDatabase`

Key here is that the two standalone deployments will both periodically call into `agDatabase` and invoke the upsert stored procedure, creating agent jobs for that AG on both nodes.  Note that this requires the AG to have readable secondaries.

### Availability Group Mode

- Clone the repository
- Open a powershell session and change to the src folder
- Import the powershell module that contains the install scripts
- Deploy the solution against a database in the AG
- Deploy the solution against every instance which can host the primary replica (not in an AG database)
- Deploy the AutoUpsert task on all nodes which can host the AG
  - The notify operator must exist on the instance or the job will not be created
- Deploy the UpdateReplicaStatus job against the AG solution

```powershell
Import-Module .\tsqlscheduler -Force

# Deploy once in AG mode
Install-SchedulerSolution -Server primaryNode -Database agDatabase

# Deploy once potential primary per-node (needed once per node only, not once per AG)
Install-SchedulerSolution -Server primaryNode -Database Utility
Install-SchedulerSolution -Server secondaryNode -Database Utility

# Create the job on every node that can host the primary
Install-AutoUpsertJob -Server primaryNode -Database Utility -TargetDatabase agDatabase -NotifyOperator "Test Operator"
Install-AutoUpsertJob -Server secondaryNode -Database Utility -TargetDatabase agDatabase -NotifyOperator "Test Operator"
```

In an instance hosting multiple availability groups, the `Utility` database needs to contain one `AutoUpsert` task for every AG.

If the Utility database on each instance is going to be used to schedule instance tasks (rather than just the tasks in `agDatabase`) an additional pair of tasks would be required:

```powershell
Install-AutoUpsertJob -Server primaryNode -Database Utility -TargetDatabase Utility -NotifyOperator "Test Operator"
Install-AutoUpsertJob -Server secondaryNode -Database Utility -TargetDatabase Utility -NotifyOperator "Test Operator"
```

### Standalone (Instance) Mode

- Clone the repository
- Open a powershell session and change to the src folder
- Import the powershell module that contains the install scripts
- Deploy the solution mode against the target instance
- Deploy the AutoUpsert task on the instance
  - The notify operator must exist on the instance or the job will not be created.

```powershell
Import-Module .\tsqlscheduler -Force

Install-SchedulerSolution -Server primaryNode -Database Utility
Install-AutoUpsertJob -Server primaryNode -Database Utility -TargetDatabase Utility -NotifyOperator "Test Operator"
```

# Uninstallation

Server objects can be removed with the [RemoveAllObjects](../src/Scripts/RemoveAllObjects.sql) SQL script.  Note that this will remove the objects but not any SQL Agent jobs which have been created.
