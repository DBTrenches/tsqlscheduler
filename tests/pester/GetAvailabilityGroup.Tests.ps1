. .\TestHelpers.ps1

# This function is only invoked directly by these tests & the underlying SQL implementation
function GetAvailabilityGroup($availabilityGroup) {
    $paramValue = "null"
    
    if($availabilityGroup -ne $null) {
        $paramValue = "'" + $availabilityGroup + "'"
    }
    $query = "select scheduler.GetAvailabilityGroupRole($paramValue) as RoleDescription"

    $result = Invoke-Sqlcmd -ServerInstance . -Database tsqlscheduler -Query $query
    return $result.RoleDescription
}

Describe "Function GetAvailabilityGroup" {
    It "returns primary when ALWAYS_PRIMARY is passed in" {
        GetAvailabilityGroup("ALWAYS_PRIMARY") | Should Be "PRIMARY"
    }
    
    It "returns secondary when NEVER_PRIMARY is passed in" {
        GetAvailabilityGroup("NEVER_PRIMARY") | Should Be "SECONDARY"
    }
    
    It "returns blank when null is passed in" {
        GetAvailabilityGroup($null) | Should Be ""
    }
}
