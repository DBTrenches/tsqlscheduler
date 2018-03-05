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
