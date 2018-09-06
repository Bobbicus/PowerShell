#Get List of VMs running on a cluster

#Method1

$clusterNodes = Get-ClusterNode;
$VMList  = ForEach($item in $clusterNodes){
    Get-VM -ComputerName $item.Name
    }

#Match a particular VM by name change %VMName%
$VMMatch  = $VMList | Where {$_.Name -like "%VMName%*"}

#Get Net Adpater information of a particular Machine information for a device. 
$VMMatch | Get-VMNetworkAdapter

#Method2

$clusterResource = Get-ClusterResource -Cluster 791941-hypclus1 | Where ResourceType -eq "Virtual Machine" | Select-Object Name,State,OwnerNode

