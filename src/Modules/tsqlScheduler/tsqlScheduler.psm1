Function Install-SchedulerSolution 
{
    [cmdletbinding()]
    Param (
        [string] $server
        ,[string] $database
        ,[boolean] $agMode = $false
        ,[string] $availabilityGroup
    )

    $deployMode = if($agMode){"IsAGMode"}else{"IsStandaloneMode"}
    $compileInclude = Import-Csv ..\deploy\compileInclude.csv

    $files += $compileInclude | Where-Object { $_."$deployMode" -match $true } 

    $files | foreach-object { 
        Write-Verbose $_.fileName
        Invoke-SqlCmd -ServerInstance $server -Database $database -InputFile $_.fileName 
    }

    $instanceGuid = [System.Guid]::NewGuid().ToString()
    $instanceFunction = @"
    create or alter function scheduler.GetInstanceId()
    returns table
    as
    return (
        select cast('$instanceGuid' as uniqueidentifier) as Id
    );
"@
    Invoke-SqlCmd -ServerInstance $server -Database $database -Query $instanceFunction

    if($agMode)
    {
        $availabilityGroupFunction = @"
        create or alter function scheduler.GetAvailabilityGroup()
        returns table
        as
        return (
            select cast('$availabilityGroup' as nvarchar(128)) as AvailabilityGroup
        );
"@
        Invoke-SqlCmd -ServerInstance $server -Database $database -Query $availabilityGroupFunction
    }
    
}

Function Install-AutoUpsertJob 
{
    [cmdletbinding()]
    Param (
        [string] $Server
        ,[string] $Database
        ,[string] $TargetDatabase
        ,[string] $NotifyOperator
    )

    # conform to naming convention of $ownLocation-$target-$task
    # but do not double-prefix self-reference/standalone AutUpsert jobs
    if($Database -eq $TargetDatabase){
        $prefix = $TargetDatabase
    }else{
        $prefix = $Database + "-" + $TargetDatabase
    }

    $jobIdentifier = $prefix + "-UpsertJobsForAllTasks"
    $query = "
        insert into scheduler.Task
        ( Identifier, TSQLCommand, StartTime, FrequencyType, FrequencyInterval, NotifyOnFailureOperator, IsNotifyOnFailure )
        values
        ( '$jobIdentifier', 'exec $TargetDatabase.scheduler.UpsertJobsForAllTasks', '00:00', 3, 10, '$NotifyOperator', 0 );"

    Invoke-SqlCmd -ServerInstance $Server -Database $Database -Query $query
    Invoke-SqlCmd -ServerInstance $Server -Database $Database -Query "exec scheduler.CreateJobFromTask @identifier = '$jobIdentifier', @overwriteExisting = 1;"
}

Function Install-ReplicaStatusJob 
{
    [cmdletbinding()]
    Param (
        [string] $Server
        ,[string] $Database
        ,[string] $NotifyOperator
    )

    $jobIdentifier = $Database + "-RecordReplicaStatus"
    $query = "
        insert into scheduler.Task
        ( Identifier, TSQLCommand, StartTime, FrequencyType, FrequencyInterval, IsCachedRoleCheck, NotifyOnFailureOperator, IsNotifyOnFailure )
        values
        ( '$jobIdentifier', 'exec $Database.scheduler.UpdateReplicaStatus', '00:00', 3, 1, 0, '$NotifyOperator', 0 );"

    Invoke-SqlCmd -ServerInstance $Server -Database $Database -Query $query
    Invoke-SqlCmd -ServerInstance $Server -Database $Database -Query "exec scheduler.CreateJobFromTask @identifier = '$jobIdentifier', @overwriteExisting = 1;"
}

Function UnInstall-SchedulerSolution
{
    [cmdletbinding()]
    Param (
        [string] $Server
        ,[string] $Database
    )

    $query = "update scheduler.task set IsDeleted = 1;"
    Invoke-SqlCmd -ServerInstance $Server -Database $Database -Query $query

    $query = "exec scheduler.UpsertJobsForAllTasks;"
    Invoke-SqlCmd -ServerInstance $Server -Database $Database -Query $query

    $query = Get-Content "RemoveAllObjects.sql" | Out-String
    Invoke-SqlCmd -ServerInstance $Server -Database $Database -Query $query
}

Export-ModuleMember Install-SchedulerSolution
Export-ModuleMember Install-AutoUpsertJob
Export-ModuleMember Install-ReplicaStatusJob
Export-ModuleMember UnInstall-SchedulerSolution