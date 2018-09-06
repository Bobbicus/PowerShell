
#Adds VMs to HA cluster.  


#lists the VMs and give you a warning prompt so you can review VMs before proceeding.
#Uses the VMs from C:\rs-pkgs\VMOrder.csv so exludes the DCs  
#Could us an array instead $VMlist = ("VM1","VM2","VM3")
$VMlist = #Import-Csv 'C:\rs-pkgs\VMOrder.csv' 
Do
{
    Write-Host "`nProceeding will add the following VMs to the Cluster" -NoNewline
    Write-Host " [Y/N]" -NoNewline
    $YesNo = Read-Host " "

    If (($YesNo -ne "Y") -and ($YesNo -ne "N"))
    {
        Write-Host "Input Error, enter Y or N." -ForegroundColor Red
    }    
      If ($YesNo -eq "Y") 
    {
        foreach($VM in $VMlist) {

        #Add VM as a cluster role. uses local cluster and assumes same name as VM.  You can specify a cluster and name shown in cluster manager
        Add-ClusterVirtualMachineRole -VMName $VM
        #Write-host "yep"
        }


    }
    If ($YesNo -eq "N")
    {
    Write-Host "No selected. Exiting code..." -ForegroundColor Red
    #Break
    }


}
Until (($YesNo -eq "Y") -or ($YesNo -eq "N"))

