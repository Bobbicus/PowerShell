#Get shutown action for VM to check for VMs configured to save. If clustered you shouldn't have to use save.  
#If set to save it uses disk space to match the size of RAM so it can save the VM state if there is an unexpected hyp shutdown
$clusterNodes = Get-ClusterNode;
$VMList  = ForEach($item in $clusterNodes){
    Get-VM -ComputerName $item.Name | Select-Object Name,AutomaticStopAction
    }

