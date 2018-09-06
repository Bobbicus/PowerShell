#VM resource metering on standalone Hyp

<#
AggregatedDiskDataRead and AggregatedDiskDataWritten are the averages since we started counting 
Either since we ran Enable-VMResourceMetering or Reset-VMResourceMetering 

Example output:   

VMName   Read Write TotalIO
------   ---- ----- -------
Win2016   707   536    1243
2016Srv1  393   199     592

#>

#Before using Measure-VM you need to enable resource metering.  this will do it for all VMs
#You could supply individual or a list of VMs instead
$VMs = Get-VM
foreach ($VM in $VMS)
{
    Enable-VMResourceMetering -VMName $VM.name
}

#Get the Disk IO stats for the VMs orders by highest Total IO
Get-VM | Measure-VM | select VMName, #AggregatedDiskDataRead,AggregatedDiskDataWritten,MeteringDuration.Seconds
    
    @{Expression={$_.AggregatedDiskDataRead};Label="Read"},
    @{Expression={$_.AggregatedDiskDataWritten};Label="Write"},
    @{Expression={$_.AggregatedDiskDataRead + $_.AggregatedDiskDataWritten};Label="TotalIO"} | Sort-Object TotalIO -Descending  | Format-Table -AutoSize

<#
#Get all VMS and reset resource metering 
$VMs = Get-VM
foreach ($VM in $VMS)
{
    Reset-VMResourceMetering -VMName $VM.name
}

#Get all VMS and disable resource metering 

$VMs = Get-VM
foreach ($VM in $VMS)
{
    Disable-VMResourceMetering -VMName $VM.name
}
#>