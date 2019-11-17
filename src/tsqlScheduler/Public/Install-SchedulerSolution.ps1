Function Install-SchedulerSolution {
    [cmdletbinding()]
    Param (
        [string] $server
        , [string] $database
    )

    $files = Get-ChildItem $PSScriptRoot\..\SQL\ -Recurse -Filter *.sql | Select-Object FullName

    Write-Verbose ">>>>>>> $server"
    Write-Verbose ">>>>>>> $database"
    Write-Verbose "--------------------------------------------------------------------"

    Invoke-SqlCmd -ServerInstance $server -Database $database -Query "create schema scheduler authorization dbo;"

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

    Write-Verbose "--------------------------------------------------------------------"

    $files | foreach-object { 
        Write-Verbose $_.FullName
        Invoke-SqlCmd -ServerInstance $server -Database $database -InputFile $_.FullName
    }
}
