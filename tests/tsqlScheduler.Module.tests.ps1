Import-Module $PSScriptRoot\..\src\Modules\tsqlScheduler -Force

$module = "tsqlScheduler"

Describe "Import-Module $module" {
  It "should export at least one function" {
    @(Get-Command -Module $module).Count | Should BeGreaterThan 0
  }
}