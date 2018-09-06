$ContentMatch = Read-Host "What content to match"
$Site = Read-Host "Site to check"
$GetSite = Invoke-WebRequest -uri $Site
if ($GetSite.RawContent.Contains($ContentMatch))
{
write-host "Site content match ok" -ForegroundColor Green
    if ($GetSite.StatusCode -eq "200")
    {


}
else
{
Write-Host "Content Match Error" -ForegroundColor Red
$GetSite.StatusCode
}

