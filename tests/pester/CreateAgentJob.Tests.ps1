. .\SQLAgentHelpers.ps1

Describe "Procedure CreateAgentJob" {
    It "should create a job when the job doesnt exist" {
        CleanupExistingAgentJob
	    CreateAgentJob
	    CheckIfAgentJobExists | Should Be $true
    }
}
