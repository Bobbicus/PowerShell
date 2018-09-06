#VM resource metering on clustered VMs
<#
AggregatedDiskDataRead and AggregatedDiskDataWritten are the averages since we started counting 
Either since we ran Enable-VMResourceMetering or Reset-VMResourceMetering 


Example output

VMName          Read Write TotalIO
------          ---- ----- -------
Winjas-DB1      2387  1229    3616
Winjas-OM1        14   326     340
Winjas-VMM1        2   182     184
Winjas-VMM2       60    71     131
Winjas-GW1         8    82      90
Winjas-MGMT1      59    17      76
Winjas-DB2        10    58      68
DiogoWinSrv2016    0    12      12
BobVM2             1     4       5
AG DB2             0     0       0
AG DB1             0     0       0

#>




#View all VMs on a cluster
$clusterNodes = Get-ClusterNode
$VMList  = ForEach($Node in $ClusterNodes){
    Get-VM -ComputerName $Node.Name
    }

$VMList

#Before using Measure-VM you need to enable resource metering.  this will do it for all VMs
#You could supply individual or a list of VMs instead
ForEach($Node in $ClusterNodes)
{
    Get-VM -ComputerName $Node.Name  | Enable-VMResourceMetering
}


#Get the Disk IO stats for the VMs orders by highest Total IO|
$VMResourceStats = ForEach($Node in $ClusterNodes){
 Get-VM -ComputerName $Node.Name | Measure-VM | select VMName, #AggregatedDiskDataRead,AggregatedDiskDataWritten,MeteringDuration.Seconds
    @{Expression={$_.AggregatedDiskDataRead};Label="Read"},
    @{Expression={$_.AggregatedDiskDataWritten};Label="Write"},
    @{Expression={$_.AggregatedDiskDataRead + $_.AggregatedDiskDataWritten};Label="TotalIO"} 
    }
$VMResourceStats | Sort-Object TotalIO -Descending | Format-Table -AutoSize


<#

#Get all VMs on cluster and reset resource metering 
$VMs = Get-VM
ForEach($Node in $ClusterNodes)
{
   Get-VM -ComputerName $Node.Name  | Reset-VMResourceMetering 
}

#Get all VMs on cluster and disable resource metering 

$VMs = Get-VM
ForEach($Node in $ClusterNodes)
{
    Get-VM -ComputerName $Node.Name | Disable-VMResourceMetering 
}
#>