if($agMode){$global:server=($replicas | Where-Object "Role" -eq "Primary").Name}
if($agMode){$global:notifyOperator=$ag.NotifyOperator}
if($agMode){$global:database=$ag.LocalDB}
if($agMode){$global:agDatabase=$ag.HADB}
