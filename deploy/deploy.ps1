param (
    [parameter(position=1)] $deployMode 
)

$currentDirectory = (Get-Item -Path ".\" -Verbose).FullName
if(!($currentDirectory.EndsWith("tsqlScheduler\src"))) {
    $message = "You must navigate to tsqlScheduler/src in order to deploy the Scheduler Solution."
    throw $message
}

$message = "Are you deploying to an Availability Group or a Single Instance?
[1] Availability Group
[2] Single Instance
Your selection"

# Allow common-sense input
if ($deployMode -eq "HA") {$deployMode = 1}
if ($deployMode -eq "AG") {$deployMode = 1}
if ($deployMode -eq "Availability Group") {$deployMode = 1}
if ($deployMode -eq "SI") {$deployMode = 2}
if ($deployMode -eq "Single") {$deployMode = 2}
if ($deployMode -eq "Single Instance") {$deployMode = 2}

if(!(($deployMode -eq 1) -or ($deployMode -eq 2))){
    $selection = Read-Host $message
}else{
    $selection = $deployMode
}

while(($selection -ne 1) -and ($selection -ne 2))
{
    $message = "Please select a valid deployment mode or press [X] to abort the deployment."
    
    if ($selection -eq "AG") {$selection = 1}
    if ($selection -eq "SI") {$selection = 2}
    if ($selection -eq "Single") {$selection = 2}

    if ($selection -eq "X") {
        Write-Host "The deploy will abort."
        return
    }
    
    $selection = Read-Host $message
}

if($selection -eq 1) {
    $agMode = $true
    $message = "Deploying in AVAILABILITY GROUP mode...`n
Please get your AG Name ready..."
}else{
    $agMode = $false
    $message = "Deploying to a SINGLE INSTANCE...`n
Please get your Server Name ready..."
}

Write-Host `n$message

..\deploy\setInput -agMode $agMode

..\deploy\testInput -agMode $agMode -agName $agName -server $server -notifyOperator $notifyOperator -database $database -agDatabase $agDatabase -replicas $replicas

Import-Module .\Modules\tsqlScheduler

if($globalErrorCount -eq 0) {
    $message = "All inputs passed validation. Deploying in 5 seconds...`n"
    # CTRL+C point
    Write-Host $message 
    
    if($agMode){
        Write-Host "Deploying HIGH-AVAILABILITY."
        Start-Sleep 5
        ..\deploy\deploy.ag -agName $agName -replicas $replicas -server $server -database $database -agDatabase $agDatabase -notifyOperator $notifyOperator 
    }
    else {
        Write-Host "Deploying STANDALONE."
        Start-Sleep 5
        ..\deploy\deploy.standalone -server $server -database $database -notifyOperator $notifyOperator
    }
} else {
    $message = "Inputs did not pass validation. Deploy aborted."
    throw $message
}
