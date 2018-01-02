# setInput
param(
    [boolean][parameter(mandatory=$true)] $agMode
    ,[string] $agName
) 
$global:agMode=$agMode

if($agMode){
    if($agName -eq $null){
        $global:agName=Read-Host "Enter the AG name"
    }else{
        $global:agName=$agName
    }
}else{$global:agName="No_agName__AG_Mode_Is_False"} # dummy non-zero string for testInput

if($agMode){
    $configFileExists=Test-Path ..\deploy\servers\$agName.json
    if($configFileExists -eq $false){..\deploy\createConfigFile} 
}
if($agMode){$global:ag = Get-Content ..\deploy\servers\$agName.json | ConvertFrom-Json}
if($agMode){
    $global:replicas = $ag.replicas | Where-Object {$_.IsSchedulerExcluded -ne $true}
}else{$global:replicas="No_Replicas__AG_Mode_Is_False"}

# initialize vars
$global:agDatabase=$null
$global:server=$null
$global:database=$null
$global:notifyOperator=$null
# set var values from config
..\deploy\tryParseVars

if($agMode){
    while($agDatabase -eq $null){
        Write-Host "agDatabase cannot be NULL."
        $global:agDatabase=Read-Host "Enter the name of the HIGHLY AVAILABLE database"
    }
}

if($server -eq $null){$global:server=Read-Host "Enter the local server name"}
if($database -eq $null){$global:database=Read-Host "Enter the local database name"}
if($notifyOperator -eq $null){$global:notifyOperator=Read-Host "Enter the name of the operator"}