
#Check CSV state and move to hard coded Hyp node
#Need to check what other states the CSV can be in to add to loop

$CSVState = Get-ClusterSharedVolume

foreach ($CSV in $CSVState)
{

    if ($CSV.Name -match "VM_DATA_DEDUP")
    {
        if ($CSV.OwnerNode -match "Winjas-HV1")
        {
            Write-Host "CSV is on correct node"
        }
        if ($CSV.OwnerNode -notmatch "Winjas-HV1")
        {
            Write-Host "CSV is NOT on correct node"
            Move-ClusterSharedVolume $CSV.Name -Node "WINJAS-HV1"
        }
    }
    if ($CSV.Name -match "VM_DATA_NODEDUP")
    {
        if ($CSV.OwnerNode -match "Winjas-HV1")
        {
            Write-Host "CSV is on correct node"
        }
        if ($CSV.OwnerNode -notmatch "Winjas-HV1")
        {
            Write-Host "CSV is NOT on correct node"
            Move-ClusterSharedVolume $CSV.Name -Node "WINJAS-HV1"
        }
    }

}