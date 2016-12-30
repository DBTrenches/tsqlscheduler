function GetAvailabilityGroup_Primary {
    $result = Invoke-Sqlcmd -ServerInstance . -Database tsqlscheduler -Query "select scheduler.GetAvailabilityGroupRole('ALWAYS_PRIMARY') as Result"
    return $result.Result
}

function GetAvailabilityGroup_Secondary {
    $result = Invoke-Sqlcmd -ServerInstance . -Database tsqlscheduler -Query "select scheduler.GetAvailabilityGroupRole('NEVER_PRIMARY') as Result"
    return $result.Result
}

function GetAvailabilityGroup_Null {
    $result = Invoke-Sqlcmd -ServerInstance . -Database tsqlscheduler -Query "select scheduler.GetAvailabilityGroupRole(null) as Result"
    return $result.Result
}