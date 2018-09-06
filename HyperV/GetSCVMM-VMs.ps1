
#Get list of VMs matching name
Get-SCVirtualMachine | Where-Object {$_.Name -like "*VMName*"} | Select-Object Name, VMHost 


#Get VMs on a particular host
Get-SCVirtualMachine | Where-Object {$_.VMHost -eq "*VMName*"} | Select-Object Name, VMHost 


#Get VM and Status
Get-SCVirtualMachine | Where-Object {$_.Name -like "*VMName*"} | Select-Object Name,VMHost,Status



#Get list of Hosts with particular VM on 
$VMHostList = Get-SCVirtualMachine | Where-Object {$_.Name -like "*VMName*" -or $_.Name -like "*VMName*"} | Select-Object VMHost

#Get All VMS on each of the hosts
foreach ($vm in $VMHostList)
{
    Get-SCVirtualMachine | Where-Object {$_.VMHost -eq $vm.VMHost} | Select-Object Name, VMHost 
}