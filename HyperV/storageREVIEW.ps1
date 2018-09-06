$CSV = Import-Csv -Path C:\rs-pkgs\VMList.csv
$VMs = $CSV.Name
$SourcePath = $CSV.SourcePath
$SourcePathVHD1 = $CSV.SourceVHD1
$SourcePathVHD2 = $CSV.SourceVHD2
$DestionationPathVHD1 = $CSV.DestinationVHD1
$DestionationPathVHD2 = $CSV.DestinationVHD2

$i=0
Foreach($VM in $VMs){

$innerSourcePath = $SourcePath[$i]
$innerSourcePathVHD1 = $SourcePathVHD1[$i]
$innerSourcePathVHD2 = $SourcePathVHD2[$i]
$innerDestPath1 = $DestionationPathVHD1[$i]
$innerDestPath2 = $DestionationPathVHD2[$i]

Write-Host "Name: $vm"
Write-Host "Moving $VM now..." -ForegroundColor Yellow

    Move-VMStorage $VM -VirtualMachinePath $innerSourcePath -SnapshotFilePath $innerSourcePath -SmartPagingFilePath $innerSourcePath `
        -VHDs @(@{"SourceFilePath" = "$innerSourcePathVHD1"; "DestinationFilePath" = "$innerDestPath1"}, @{"SourceFilePath" = "$innerSourcePathVHD2"; "DestinationFilePath" = "$innerDestPath2"})

        Write-Host "$VM done!" -ForegroundColor Green


$i++
}