$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'
. "$here\$sut"

Describe "GetAvailabilityGroup" {
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
