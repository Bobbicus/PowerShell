#Get list of VMs matching a particular name like WEV-*** change *VMName*
$VM8189list = Get-SCVirtualMachine | Where-Object {$_.Name -like "*VMName*" -or $_.Name -like "*VMName*"} | Select-Object Name,Status,VMHost 
#Exclude certain VMs
$VMList = $VM8189list | Where-Object {$_.Name -ne "*VMName*"}  

#Loop through list of VMs and upgrade CPU and RAM.  Need to shutdown before change see StopStartSCVMM-VMs.ps1
foreach($VM in $VMList ){

   Set-SCVirtualMachine -VM $VM.Name -CPUCount 12 -MemoryMB 65536 -DynamicMemoryEnabled $false


}