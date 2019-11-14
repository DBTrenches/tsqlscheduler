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
    $compileInclude = Import-Csv $PSScriptRoot\..\..\compileInclude.csv

    $files += $compileInclude | Where-Object { $_."$deployMode" -match $true } 

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
        Write-Verbose $_.fileName
        Invoke-SqlCmd -ServerInstance $server -Database $database -InputFile "$PSScriptRoot\..\..\$($_.fileName)" 
    }

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
