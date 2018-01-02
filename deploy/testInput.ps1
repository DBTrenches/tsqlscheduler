param(
    [boolean][parameter(mandatory=$true)] $agMode
    ,[string][parameter(mandatory=$true)] $agName
    ,[parameter(mandatory=$true)] $replicas
    ,[string][parameter(mandatory=$true)] $server
    ,[string][parameter(mandatory=$true)] $notifyOperator
    ,[string][parameter(mandatory=$true)] $database
    ,[string] $agDatabase
)

# TODO:
# validate Server is connectable before proceeding

$global:globalErrorCount = 0

..\deploy\testInput.standalone -server $server -database $database -notifyOperator $notifyOperator
if($agMode){
    ..\deploy\testInput.ag -agName $agName -replicas $replicas -agDatabase $agDatabase -notifyOperator $notifyOperator
}


