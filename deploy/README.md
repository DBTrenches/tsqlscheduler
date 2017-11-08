# Deployment

Deploying to an AG follows the below footprint. 

![](../doc/img/AG1-sample-deployment.png)

## 1.1 Deployment

In release 1.1, deployment occurs by executing powershell commands from the Module explicitly against the target servers & databases with the appropriate `$agMode` flag for the instance. 

### Availability Group Mode

- Clone the repository
- Open a powershell session and change to the src folder
- Import the powershell module that contains the install scripts
- Deploy the solution in AG mode against a database in the AG
- Deploy the solution in standalone mode against every instance which can host the primary replica (not in an AG database)
- Deploy the AutoUpsert task on all nodes which can host the AG
  - The notify operator must exist on the instance or the job will not be created
- Deploy the UpdateReplicaStatus job against the AG solution

```powershell
Import-Module .\Modules\tsqlscheduler

# Deploy once in AG mode
Install-SchedulerSolution -Server primaryNode -Database agDatabase -agMode $true -AvailabilityGroup AGName

# Deploy once potential primary per-node in standalone mode (needed once per node only, not once per AG)
Install-SchedulerSolution -Server primaryNode -Database Utility -agMode $false
Install-SchedulerSolution -Server secondaryNode -Database Utility -agMode $false

# Create the job on every node that can host the primary
Install-AutoUpsertJob -Server primaryNode -Database Utility -TargetDatabase agDatabase -NotifyOperator "Test Operator"
Install-AutoUpsertJob -Server secondaryNode -Database Utility -TargetDatabase agDatabase -NotifyOperator "Test Operator"

# Create the job that keeps track of the replica status
Install-ReplicaStatusJob -Server primaryNode -Database agDatabase -NotifyOperator "Test Operator"
```

### Standalone (Instance) Mode

- Clone the repository
- Open a powershell session and change to the src folder
- Import the powershell module that contains the install scripts
- Deploy the solution in standalone mode against the target instance
- Deploy the AutoUpsert task on the instance
  - The notify operator must exist on the instance or the job will not be created.

```powershell
Import-Module .\Modules\tsqlscheduler

# Deploy in standalone mode
Install-SchedulerSolution -Server primaryNode -Database Utility -agMode $false
Install-AutoUpsertJob -Server primaryNode -Database Utility -TargetDatabase Utility -NotifyOperator "Test Operator"
```


