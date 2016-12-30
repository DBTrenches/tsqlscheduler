$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'
. "$here\$sut"

Describe "IsEnabled" {
    It "should execute enabled tasks" {
        IsEnabled($true) | Should Be 1
    }

    It "should not execute disabled tasks" {
        IsEnabled($false) | Should Be 0
    }
}
