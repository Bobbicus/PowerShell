$CSVS = Get-ClusterSharedVolume 
foreach ($Vol in $CSVS)
{
 Get-ClusterSharedVolume $Vol.Name| fc *
}

$CSVS | Select-Object SharedvolumeInfo | fc * | gm