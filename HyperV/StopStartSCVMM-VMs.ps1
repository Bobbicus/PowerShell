#Get list of Hosts with particular VM on change VMName to anme or part of name
$VM8090list = Get-SCVirtualMachine | Where-Object {$_.Name -like "*VMName*" -or $_.Name -like "*VMName*"} | Select-Object Name,Status
#Exclude certain VMs
$VMList = $VM8090list | Where-Object {$_.Name -ne "VMName"}  

#Loop through VMs stop
foreach($VM in $VMList){
#write-host $VM.Name

Stop-SCVirtualMachine -VM $VM.Name

}


#Run below to start the VMs

#Loop through VMs and either start
foreach($VM in $VMList){
#write-host $VM.Name

Start-SCVirtualMachine -VM $VM.Name

}
