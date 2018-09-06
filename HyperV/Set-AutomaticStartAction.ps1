$MaintHyps = @("826021-chypv13","826022-chypv14","826023-chypv15","826024-chypv16","826025-chypv17","826026-chypv18","826027-chypv19","826028-chypv20","826029-chypv21","826030-chypv22","826062-chypv23","826063-chypv24","826064-chypv25","826065-chypv26","826066-chypv27","826067-chypv28","861608-chypv29","861611-chypv30","861612-chypv31","861613-chypv32")
$VMs = foreach ($Hyp in $MaintHyps)
{
    Get-VM -ComputerName $Hyp
}

$XSQL = $VMs | Where-Object {$_.Name -like "*-XSQL*" -and $_.State -eq "Running"}

$XSQL | Select-Object Name,AutomaticStartAction

foreach ($XSQLVM in $XSQL)
{
   $VMs | Where-Object {$_.Name -like  $XSQLVM.Name} | Set-Vm -AutomaticStartAction Nothing
}

$XSQL | Select-Object Name,AutomaticStartAction,State
