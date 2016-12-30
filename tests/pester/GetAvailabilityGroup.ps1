function GetAvailabilityGroup($availabilityGroup) {
    $paramValue = "null"
    
    if($availabilityGroup -ne $null) {
        $paramValue = "'" + $availabilityGroup + "'"
    }
    $query = "select scheduler.GetAvailabilityGroupRole($paramValue) as Result"

    $result = Invoke-Sqlcmd -ServerInstance . -Database tsqlscheduler -Query $query
    return $result.Result
}