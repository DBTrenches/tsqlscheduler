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
# function is schema-bound by check constraint. skip re-deploy if already exists. but do check that it's valid
    if((Invoke-SqlCmd -ServerInstance $server `
        -Database $database `
        -Query "select scheduler.GetDatabase() as dbf" `
        -ErrorAction SilentlyContinue).dbf -ne $database)
    {
        Invoke-SqlCmd -ServerInstance $server -Database $database -Query $dbFunction
    }

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
