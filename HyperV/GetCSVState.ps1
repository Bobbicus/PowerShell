
#Get CSV state
#Need to check what other states the CSV can be in to add to loop

$CSVState = Get-ClusterSharedVolume


foreach ($CSV in $CSVState)
{

    if ($CSVIOState -match "NoFaults")
    {
        Write-Host "CSV in Direct mode"
        
    }
    if ($CSVIOState -match "NoDirectIO")
    {
        Write-Host "CSV in redirected mode"
        Move-CSV

    }
}