#GEt bin files of servers in Autoshutdown set to saved state

$AllVHDs = Get-ChildItem C:\ClusterStorage\Volume2\*.bin -Recurse | Select-Object FullName,Length
$AllVHDs | gm
