#Get a particular VM on cluster by matching name
$VMName = read-host "Enter VM Name"
$clusterNodes = Get-ClusterNode;
$VMList  = ForEach($item in $clusterNodes){
    Get-VM -ComputerName $item.Name | Where {$_.Name -eq $VMName}
    }

#Get status of VM Replication for the device
$VMList | Measure-VMReplication | Select-Object Name,State,Health,LReplTime | Format-Table -AutoSize