Function Install-SchedulerSolution 
{
    [cmdletbinding()]
    Param (
        [string] $server
        ,[string] $database
        ,[boolean] $agMode = $false
        ,[string] $availabilityGroup
        ,[boolean] $versionBump = $false
    )

    $deployMode = if($agMode){"IsAGMode"}else{"IsStandaloneMode"}
    $compileInclude = Import-Csv ..\deploy\compileInclude.csv

    if($versionBump){
        $files += $compileInclude | Where-Object { 
            ($_."$deployMode" -match $true) -and
            (($_.fileName).StartsWith(".\Tables") -eq $false) # ignore stateful data objs on version bump
        }
    }else{
        $files += $compileInclude | Where-Object { $_."$deployMode" -match $true } 
    }

    Write-Verbose ">>>>>>> $server"
    Write-Verbose ">>>>>>> $database"
    Write-Verbose "--------------------------------------------------------------------"

    $dbFunction = @"
create or alter function scheduler.GetDatabase()
returns sysname
as
begin;
    return '$database';
end;
"@
    Invoke-SqlCmd -ServerInstance $server -Database $database -Query $dbFunction

    if($versionBump){
        [decimal]$version=(Invoke-Sqlcmd `
            -ServerInstance $server `
            -Database $database `
            -Query "select [Version] from scheduler.GetVersion()").Version
        
# credit to https://stackoverflow.com/a/5429048/4709762
        $ToNatural = { [regex]::Replace($_, '\d+', { $args[0].Value.PadLeft(20) }) }

        gci ..\deploy\patchfiles -Directory | Where-Object {$_.Name -gt $version} | Sort-Object $ToNatural | % {
            gci $_.FullName -Recurse | % {
                $f=$_.FullName
                $n=$_.Name
                Write-Verbose "Stateful migration script found to bump from version '$version'"
                Write-Verbose "Deploying patchfile [$n] to [$server].[$database]"
                Invoke-Sqlcmd -ServerInstance $server -Database $database -InputFile "$f"
            }
        }
    }
    
    $files | foreach-object { 
        Write-Verbose $_.fileName
        Invoke-SqlCmd -ServerInstance $server -Database $database -InputFile $_.fileName 
    }

    Write-Verbose "--------------------------------------------------------------------"

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
exec scheduler.UpsertTask
    @action = 'INSERT', 
    @jobIdentifier = '$jobIdentifier', 
    @tsqlCommand = N'exec $TargetDatabase.scheduler.UpsertJobsForAllTasks;', 
    @startTime = '00:00', 
    @frequencyType = 3, 
    @frequencyInterval = 1, 
    @notifyOperator = '$NotifyOperator',
    @notifyLevelEventlog = 2, 
    @isNotifyOnFailure = 0,
    @overwriteExisting = 1;" # allow error-free redeploy of same AG after logical delete of local upsert job

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
exec scheduler.UpsertTask
    @action = 'INSERT', 
    @jobIdentifier = '$jobIdentifier', 
    @tsqlCommand = N'exec $Database.scheduler.UpdateReplicaStatus;', 
    @startTime = '00:00', 
    @frequencyType = 3, 
    @frequencyInterval = 1, 
    @notifyOperator = '$NotifyOperator', 
    @notifyLevelEventlog = 2,
    @isNotifyOnFailure = 0,
    @overwriteExisting = 1;"

    Invoke-SqlCmd -ServerInstance $Server -Database $Database -Query $query
    Invoke-SqlCmd -ServerInstance $Server -Database $Database -Query "exec scheduler.CreateJobFromTask @identifier = '$jobIdentifier', @overwriteExisting = 1;"
}

Function UnInstall-SchedulerSolution
{
    [cmdletbinding()]
    Param (
        [string] $agName
        ,[boolean] $agMode=$true
    )

    ..\deploy\setInput -agMode $agMode -agName $agName

    $setTaskDeletedQuery = "update scheduler.task set IsDeleted = 1;"
    $deleteAllHAJobsQuery = "exec scheduler.UpsertJobsForAllTasks;"
    $removeAllObjectsQuery = Get-Content "RemoveAllObjects.sql" | Out-String
    $disableStopAllJosQuery = Get-Content "HardStop.sql" | Out-String

    if($agMode){
        Write-Host "Uninstalling HA Scheduler from AG [$agName]"
        Write-Verbose $ag
        Start-Sleep 5

        $deleteLocalUpsertJobQuery="update top(1) scheduler.task set IsDeleted = 1 where Identifier='$Database-$agDatabase-UpsertJobsForAllTasks';"
        
        Write-Verbose ">>>>>>> $server"
        Write-Verbose ">>>>>>> $agDatabase"
        Write-Verbose "--------------------------------------------------------------------" 

        Write-Verbose $setTaskDeletedQuery
        Invoke-SqlCmd -ServerInstance $Server -Database $agDatabase -Query $setTaskDeletedQuery
        Write-Verbose "Disabling and stopping all jobs in the scheduler..."
        Invoke-SqlCmd -ServerInstance $Server -Database $Database -Query $disableStopAllJosQuery

        Write-Verbose "--------------------------------------------------------------------" 

        foreach($r in $replicas){
            $srv = $r.Name
            
            Write-Verbose ">>>>>>> $srv"
            
            Write-Verbose ">>>>>>> $Database"
            Write-Verbose $deleteLocalUpsertJobQuery"`n"
            Invoke-SqlCmd -ServerInstance $srv -Database $Database -Query $deleteLocalUpsertJobQuery

            Write-Verbose ">>>>>>> $agDatabase"
            Write-Verbose $deleteAllHAJobsQuery"`n" 
            Invoke-SqlCmd -ServerInstance $srv -Database $agDatabase -Query $deleteAllHAJobsQuery
        }

        Write-Verbose "Removing all objects...`n"
        Invoke-SqlCmd -ServerInstance $Server -Database $agDatabase -Query $removeAllObjectsQuery
    }else{ 
        Write-Host "Uninstalling Local Scheduler from Server [$server], DB [$database]"
        Start-Sleep 5

        Write-Verbose ">>>>>>> $server"
        Write-Verbose ">>>>>>> $database"
        Write-Verbose $setTaskDeletedQuery
        Invoke-SqlCmd -ServerInstance $Server -Database $Database -Query $setTaskDeletedQuery
        Write-Verbose "Disabling and stopping all jobs in the scheduler..."
        Invoke-SqlCmd -ServerInstance $Server -Database $Database -Query $disableStopAllJosQuery
        Write-Verbose $deleteAllHAJobsQuery
        Invoke-SqlCmd -ServerInstance $Server -Database $Database -Query $deleteAllHAJobsQuery
        Write-Verbose "Removing all objects..."
        Invoke-SqlCmd -ServerInstance $Server -Database $Database -Query $removeAllObjectsQuery
    }

    Write-Verbose "--------------------------------------------------------------------" 
}

Function Publish-TaskFromConfig
{
    [cmdletbinding()]
    Param (
         [string] $config
        ,[string] $server
        ,[string] $database
        ,[string] $action = 'INSERT'
    )

    $validTarget=(Get-SqlDatabase -ServerInstance $server -Name $database -ErrorAction SilentlyContinue)
    if($validTarget -eq $null){
        Write-Host "Connection not validated to [$server].[$database]. Aborting..." -ForegroundColor Red
        return
    }

    if($action -eq $null){$action='INSERT'}
    if($action -eq "UPDATE"){$action='INSERT'}
    
    $task = Get-Content -LiteralPath $config | ConvertFrom-Json
    $jobName=$task.Identifier

    if($action -eq "RENAME"){
        Write-Host "TODO: add support for renaming tasks from PS..." -ForegroundColor Red
        return
    }

    if(($action -eq 'DELETE') -and ($task.IsDeleted -ne $true)){
        Write-Host "Task '$jobName' selected for DELETION must be declared as such in config. Aborting..." -ForegroundColor Red
        notepad "$config"
        return
    }

    if(($action -ne 'DELETE') `
        -and ($action -ne 'INSERT') `
        -and ($action -ne 'UPDATE') )
    {
        Write-Host "Selected command '$action' is unsupported. Aborting..." -ForegroundColor Red
        return
    }

# Parse from config & set allowable attributes to default if missing
    $taskIdentifier = $task.Identifier
    $taskTSQLCommand = $task.TSQLCommand
    $taskStartTime = $task.StartTime
    $taskFrequencyTypeDesc = $task.FrequencyTypeDesc
    $taskFrequencyInterval = $task.FrequencyInterval
    $taskNotifyOnFailureOperator = $task.NotifyOnFailureOperator
    $taskNotifyLevelEventlog = $task.NotifyLevelEventlog
    $taskIsNotifyOnFailure = $task.IsNotifyOnFailure
    $taskIsEnabled = $task.IsEnabled
    $taskIsDeleted = $task.IsDeleted

    #if($taskNotifyOnFailureOperator -eq $null){$taskNotifyOnFailureOperator = } # TODO: parse default from relevant config
    if($taskNotifyLevelEventlog -eq $null){$taskNotifyLevelEventlog = 2} # write to windows event log
    if($taskIsNotifyOnFailure -eq $null){$taskIsNotifyOnFailure = $true}
    if($taskIsEnabled -eq $null){$taskIsEnabled = $false}
    if($taskIsDeleted -eq $null){$taskIsDeleted = $true}

    Write-Verbose "Inputs passed preliminary validation. Attempting to publish task [$jobName] to [$server].[$database]."

# Invoke-SQLCmd sucks for parameterization & Json is a text bomb so...
    $upsertTaskQuery = "
exec scheduler.UpsertTask
    @action = @action,
    @jobIdentifier = @jobIdentifier,
    @tsqlCommand = @tsqlCommand,
    @startTime = @startTime,
    @frequencyTypeDesc = @frequencyTypeDesc,
    @frequencyInterval = @frequencyInterval,
    @notifyOperator = @notifyOperator,
    @notifyLevelEventlog = @notifyLevelEventlog,
    @isNotifyOnFailure = @isNotifyOnFailure,
    @isEnabled = @isEnabled,
    @isDeleted = @isDeleted,
    @overwriteExisting = @overwriteExisting;"

    $connStr = "Server=$server;Initial Catalog=$database;Integrated Security=True"
    $conn=new-object System.Data.SqlClient.SqlConnection $connStr
    $conn.open()

    $upsertTaskCmd = New-Object System.Data.SqlClient.SqlCommand
    $upsertTaskCmd.Connection = $conn
    $upsertTaskCmd.CommandText = $upsertTaskQuery
    
    $upsertTaskCmd.Parameters.Add((New-Object Data.SqlClient.SqlParameter("@action",[Data.SQLDBType]::VarChar,6))).value = $action
    $upsertTaskCmd.Parameters.Add((New-Object Data.SqlClient.SqlParameter("@jobIdentifier",[Data.SQLDBType]::NVarChar,128))).value = $taskIdentifier
    $upsertTaskCmd.Parameters.Add((New-Object Data.SqlClient.SqlParameter("@tsqlCommand",[Data.SQLDBType]::NVarChar,-1))).value = $taskTSQLCommand
    $upsertTaskCmd.Parameters.Add((New-Object Data.SqlClient.SqlParameter("@StartTime",[Data.SQLDBType]::Time,5))).value = $taskStartTime
    $upsertTaskCmd.Parameters.Add((New-Object Data.SqlClient.SqlParameter("@FrequencyTypeDesc",[Data.SQLDBType]::VarChar,6))).value = $taskFrequencyTypeDesc
    $upsertTaskCmd.Parameters.Add((New-Object Data.SqlClient.SqlParameter("@FrequencyInterval",[Data.SQLDBType]::SmallInt))).value = $taskFrequencyInterval
    $upsertTaskCmd.Parameters.Add((New-Object Data.SqlClient.SqlParameter("@NotifyOperator",[Data.SQLDBType]::NVarChar,128))).value = $taskNotifyOnFailureOperator
    $upsertTaskCmd.Parameters.Add((New-Object Data.SqlClient.SqlParameter("@notifyLevelEventlog",[Data.SQLDBType]::Int))).value = $taskNotifyLevelEventlog
    $upsertTaskCmd.Parameters.Add((New-Object Data.SqlClient.SqlParameter("@IsNotifyOnFailure",[Data.SQLDBType]::Bit))).value = $taskIsNotifyOnFailure
    $upsertTaskCmd.Parameters.Add((New-Object Data.SqlClient.SqlParameter("@IsEnabled",[Data.SQLDBType]::Bit))).value = $taskIsEnabled
    $upsertTaskCmd.Parameters.Add((New-Object Data.SqlClient.SqlParameter("@IsDeleted",[Data.SQLDBType]::Bit))).value = $taskIsDeleted
    $upsertTaskCmd.Parameters.Add((New-Object Data.SqlClient.SqlParameter("@overwriteExisting",[Data.SQLDBType]::Bit))).value = 1

    $upsertTaskCmd.Prepare()
    $upsertTaskCmd.ExecuteNonQuery() | Out-Null
    
    $upsertTaskCmd.Parameters.Clear()
    $conn.Close()
}

Export-ModuleMember Install-SchedulerSolution
Export-ModuleMember Install-AutoUpsertJob
Export-ModuleMember Install-ReplicaStatusJob
Export-ModuleMember UnInstall-SchedulerSolution
Export-ModuleMember Publish-TaskFromConfig
