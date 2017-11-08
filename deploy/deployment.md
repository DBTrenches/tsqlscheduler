# Deployment & Removal

Powershell deployment from must occur from the src folder.

### Standalone (Instance) Mode

[`..\deploy\deploy`](deploy.ps1) with the `"Single Instance"` arg validates a few parameters and the proceeds with the following steps.  

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

