using module .\Classes\tsqlscheduler.Task.psm1

Get-ChildItem $PSScriptRoot\Public | ForEach-Object { 
  . $_
}