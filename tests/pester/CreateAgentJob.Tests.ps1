. .\SQLAgentHelpers.ps1

Describe "Procedure CreateAgentJob" {
    It "should create a job when the job doesnt exist" {
        CleanupExistingAgentJob
	    CreateAgentJob
	    CheckIfAgentJobExists | Should Be $true
    }

    It "should throw an error when trying to create a job that already exists and overwrite is not set" {
        CleanupExistingAgentJob
	    CreateAgentJob
        { CreateAgentJob } | Should Throw "Specified job name already exists"
    }

    It "should update the job when trying to create a job that already exists and overwrite is set" {
        CleanupExistingAgentJob
	    CreateAgentJob
        { CreateAgentJob -overwriteExisting 1 -command "select 1" } | Should Not Throw
	    CheckIfAgentJobExists | Should Be $true
        # Defaults to select @@servername
        GetAgentJobCommand | Should Be "select 1"
    }
}
