# setInput
param(
    [boolean][parameter(mandatory=$true)] $agMode
) 

$global:server=Read-Host "Enter the local server name"
$global:database=Read-Host "Enter the local database name"
$global:notifyOperator=Read-Host "Enter the name of the operator"

if($agMode){$global:agName=Read-Host "Enter the AG name"}else{$global:agName="x"} # dummy non-zero string for testInput
if($agMode){$global:agDatabase=Read-Host "Enter the name of the HIGHLY AVAILABLE database"}else{$global:agDatabase="x"}
if($agMode){
    $ag = Get-Content ..\deploy\servers\$agName.json | ConvertFrom-Json
    $global:replicas = $ag.replicas | Where-Object {$_.IsSchedulerExcluded -ne $true}
}else{$global:replicas="x"}
