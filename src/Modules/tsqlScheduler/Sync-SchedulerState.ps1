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

    $getTasksQ = "select * from scheduler.TaskConfig;"
    $allTasks = (Invoke-Sqlcmd -ServerInstance $fromServer -Database $fromDatabase -Query $getTasksQ)

    foreach($t in $allTasks){
        $fName = ($t.Identifier).Trim(":\").Replace("/","") # do this better...

        $fName = "$folder\$fName.json"
    
        $config = $t.Config

        $config=($config | ConvertFrom-Json | ConvertTo-Json)

        Set-Content -LiteralPath $fName -Value $config 
    }

    cd $folder

    $allTasks = (Get-ChildItem)
    foreach($t in $allTasks){
        Publish-TaskFromConfig -config $t.Name -server $toServer -Database $toDatabase
    }

    cd ..
}
