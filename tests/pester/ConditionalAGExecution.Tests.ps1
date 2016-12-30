$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'
. "$here\$sut"

Describe "ConditionalAGExecution" {
    It "should execute tasks scheduled on the primary replica" {
        ConditionalAGExecution_PrimaryExecutes | Should Be 1
    }

    It "should not execute tasks scheduled on the secondary replica" {
        ConditionalAGExecution_SecondaryDoesNotExecute | Should Be 0
    }

    It "should execute tasks when no AG is specified" {
        ConditionalAGExecution_NoAGDoesExecute | Should Be 1
    }
}
