# Migration from v1.X

To perform an in-place migration the suggested approach is:

- Sync your tasks to the file system using the v1.x module
- Run the below migration script, correcting any errors or omissions
- Remove the v1 scheduler schema and all associated agent jobs
  - Set all tasks to `Deleted`
  - Run the Upsert job on all replicas
  - Run the `RemoveAllObjects.sql` script
- Install the v2 scheduler schema
- Sync the folder to the database

```powershell
$sourceFolder = "c:\temp\MigrationExamples\Tasks"
$targetFolder = "c:\temp\MigrationExamples\Tasks-Migrated"

$rawFiles = Get-ChildItem -Path $sourceFolder

foreach($rawFile in $rawFiles) {
  $content = Get-Content -LiteralPath $rawFile -Raw 
  try {
    $taskJson = $content | ConvertFrom-Json
  } catch {
    Write-Warning "File $rawFile cannot be converted to JSON"
    continue
  }

  $requiredProperties = @(
    "Identifier",
    "TSQLCommand",
    "StartTime",
    "FrequencyType",
    "FrequencyInterval",
    "NotifyOnFailureOperator",
    "IsNotifyOnFailure",
    "IsEnabled",
    "IsDeleted",
    "NotifyLevelEventlog"
  )

  $taskProperties = $taskJson.PSObject.Properties.Name

  if($null -eq $taskProperties) {
    Write-Warning "File $rawFile is missing any properties"
    continue
  }

  $missingProperties = Compare-Object -ReferenceObject $requiredProperties -DifferenceObject $taskProperties `
    | Where-Object -Property SideIndicator -eq "<=" `
    | Measure-Object | Select-Object -ExpandProperty Count 

  if($missingProperties -gt 0) {
    Write-Warning "File $rawFile is missing $missingProperties required properties"
    continue
  }

  $task = @{}
  $task.Identifier = $taskJson.Identifier
  $task.TSQLCommand = $taskJson.TSQLCommand
  $task.StartTime = $taskJson.StartTime
  $task.FrequencyInterval = $taskJson.FrequencyInterval
  $task.NotifyOnFailureOperator = $taskJson.NotifyOnFailureOperator
  $task.IsEnabled = $taskJson.IsEnabled
  $task.IsDeleted = $taskJson.IsDeleted

  switch($taskJson.FrequencyInterval) {
    0 { $task.Frequency = "Day" }
    1 { $task.Frequency = "Hour" }
    2 { $task.Frequency = "Minute" }
    3 { $task.Frequency = "Second" }
  }

  switch ($taskJson.NotifyLevelEventlog) {
    0 { $task.NotifyLevelEventLog = "Never"  }
    1 { $task.NotifyLevelEventLog = "OnSuccess" }
    2 { $task.NotifyLevelEventLog = "OnFailure" }
    3 { $task.NotifyLevelEventLog = "Always" }
  }

  $task.TaskUid = [Guid]::NewGuid()

  Set-FolderTask $targetFolder $task #-WhatIf
}

Write-Output Done
```