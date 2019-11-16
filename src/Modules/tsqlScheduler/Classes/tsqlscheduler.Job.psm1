class Job : IEquatable[Object] {
  [Guid] $TaskUid
  [string] $Identifier
  [string] $TSQLCommand
  [string] $StartTime
  [string] $Frequency
  [int] $FrequencyInterval
  [string] $NotifyOnFailureOperator
  [bool] $IsNotifyOnfailure
  [bool] $IsEnabled
  [bool] $IsDeleted
  [int] $NotifyLevelEventLog
  
  [bool] Equals($other) {
    return (
      $this.TaskUid -eq $other.TaskUid -and `
      $this.Identifier -eq $other.Identifier -and `
      $this.TSQLCommand -eq $other.TSQLCommand -and `
      $this.StartTime -eq $other.StartTime -and `
      $this.Frequency -eq $other.Frequency -and `
      $this.FrequencyInterval -eq $other.FrequencyInterval -and `
      $this.NotifyOnFailureOperator -eq $other.NotifyOnFailureOperator -and `
      $this.IsNotifyOnfailure -eq $other.IsNotifyOnfailure -and `
      $this.IsEnabled -eq $other.IsEnabled -and `
      $this.IsDeleted -eq $other.IsDeleted -and `
      $this.NotifyLevelEventLog -eq $other.NotifyLevelEventLog
    )
  }
}