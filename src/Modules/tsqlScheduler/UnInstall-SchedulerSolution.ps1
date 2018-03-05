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
