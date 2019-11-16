Function Sync-SchedulerState
{
    [cmdletbinding()]
    Param (
         [string] $fromServer
        ,[string] $fromDatabase
        ,[string] $toServer
        ,[string] $toDatabase
        ,[string] $folder="./tasks"
    )

    if((Test-Path $folder) -eq $false){
        New-Item -ItemType Directory -Force -Path $folder
    }

    $getTasksQ = "
select  
    TaskUid,
    Identifier,
    (select 
        TaskUid,
        Identifier,
        TSQLCommand,
        StartTime,
        Frequency,
        FrequencyInterval,
        NotifyOnFailureOperator,
        IsNotifyOnFailure,
        IsEnabled,
        IsDeleted,
        NotifyLevelEventlog
    for json path, without_array_wrapper) as Config
from scheduler.Task
"

    $allTasks = @(Invoke-Sqlcmd -ServerInstance $fromServer -Database $fromDatabase -Query $getTasksQ)

    foreach($t in $allTasks){
        $fName = $t.TaskUid # do this better...
        $fName = "$folder\$fName.job.json"
        $config = $t.Config
        $config=($config | ConvertFrom-Json | ConvertTo-Json)

        Set-Content -LiteralPath $fName -Value $config 
    }

    Push-Location

    Set-Location $folder

    $allTasks = (Get-ChildItem)
    foreach($t in $allTasks){
        Publish-TaskFromConfig -config $t.Name -server $toServer -Database $toDatabase
    }

    Pop-Location
}
