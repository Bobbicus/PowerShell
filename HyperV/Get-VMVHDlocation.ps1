$clusterNodes = Get-ClusterNode | Where-Object {$_.State -eq "up"}
$VMList  = ForEach($item in $clusterNodes){
    Get-VM -ComputerName $item.Name | get-vmharddiskdrive | Select-Object VMName,Path
    }

$VMlist | Export-Csv -Path C:\rs-pkgs\VMdisklocation.csv
#Group the objects by VM, so if VM has multiuple VHDs it shows as one object.

$VMGroupList = $VMList | Group-Object VMName
$VMGroupList | Where-Object ($_.Group.Path -contains "\\123456-SOFC*")

$i = 0
#increment through the list to get a count
foreach ($VM1 in $VMGroupList)
{
   
    #write-host $VM1.Group.Path
    if ($VM1.Group.Path -like "\\123456-SOFC*")
    {
    write-host $VM1.Name,$VM1.Group.Path
    $i++
     write-host $i
    }
   
    }


foreach ($VM1 in $VMGroupList)
{
   
    #write-host $VM1.Group.Path
    if ($VM1.Group.Path -notlike "\\123456-SOFC*")
    {
    write-host $VM1.Name,$VM1.Group.Path

    }
   
    }