Function Test-FolderTasks
{
  [cmdletbinding()]
  Param (
    [Parameter(Mandatory=$true)]
    [ValidateScript({ Test-Path -Path $PSItem })]
    [ValidateNotNullOrEmpty()]
    [string] $FolderPath
  )
  $result = $true

  $rawFiles = Get-ChildItem -Path $FolderPath

  foreach($rawFile in $rawFiles) {
    $content = Get-Content -LiteralPath $rawFile -Raw 
    try {
      $taskJson = $content | ConvertFrom-Json
    } catch {
      Write-Warning "File $rawFile cannot be converted to JSON"
      $result = $false
      continue
    }

    $requiredProperties = @(
      "TaskUid",
      "Identifier",
      "TSQLCommand",
      "StartTime",
      "Frequency",
      "FrequencyInterval",
      "NotifyOnFailureOperator",
      "IsNotifyOnFailure",
      "IsEnabled",
      "IsDeleted",
      "NotifyLevelEventlog"
    )

    $taskProperties = $taskJson.PSObject.Properties.Name
  
    if($null -eq $taskProperties) {
      Write-Warning "File $rawFile has no properties"
      $result = $false
      continue
    }

    $missingProperties = Compare-Object -ReferenceObject $requiredProperties -DifferenceObject $taskProperties `
      | Where-Object -Property SideIndicator -eq "<="

    $missingCount = $missingProperties | Measure-Object | Select-Object -ExpandProperty Count 

    if($missingCount -gt 0) {
      $missingString = [string]::Join(",", $missingProperties.InputObject)
      Write-Warning "File $rawFile is missing $missingCount required properties ($missingString)"
      $result = $false
      continue
    }
  }

  $result
}