
function Create-DNSArray
{
        $DNSSuffixes = $DNSSuffixes -replace "\s",""
        #Convert the string of DNSservers to an array
        $DNSSuffixes = $DNSSuffixes.Split(",")
        return $DNSSuffixes
}


Write-Host "1 - Clear the DNS suffix list" -ForegroundColor yellow
Write-Host "2 - Use Rackspace default suffixes" -ForegroundColor Yellow
Write-Host "3 - Enter the DNS suffixes want to set on the public adapter separated by a comma (Example: a.local,b.local)" -ForegroundColor yellow
$DNSSuffixes = Read-host "Enter number"


switch ($DNSSuffixes) 
    { 
        1 {"Clear DNS Suffix List"} 
        2 {"Use Rackspace Defuault suffixes"} 
        3 {"Custom DNS Suffix list"} 
        default {"2 Use Rackspace Default suffixes"}
    }

     
  if ($DNSSuffixes -eq "3")
    {
        $DNSSuffixes = Read-host "Enter the DNS suffixes want to set on the public adapter separated by a comma (Example: a.local,b.local)"
    }   


    if ($DNSSuffixes -eq "1")
    {
        $DNSSuffixes = $null
        "blank"
    }
    elseif ($DNSSuffixes -eq "2")
    {
        $RSRegKeys = Get-ItemProperty -path HKLM:\HKEY_LOCAL_MACHINE\SOFTWARE\Rackspace
        $DClocation = $RSRegKeys.Datacenter
        if ($DClocation -like "ORD*")
        {
          $DNSSuffixes = "ord.intensive.int,intensive.int,iad.intensive.int,dfw.intensive.int,lon.intensive.int,hkg.intensive.int,syd.intensive.int"
          $DNSSuffixes = Create-DNSArray  
        }
        elseif ($DClocation -like "DFW*")
        {
           $DNSSuffixes = "dfw.intensive.int,intensive.int,ord.intensive.int,iad.intensive.int,lon.intensive.int,hkg.intensive.int,syd.intensive.int"
           $DNSSuffixes = Create-DNSArray
        }
        elseif ($DClocation -like "IAD*")
        {
          $DNSSuffixes = "iad.intensive.int,intensive.int,ord.intensive.int,dfw.intensive.int,lon.intensive.int,hkg.intensive.int,syd.intensive.int"
          $DNSSuffixes = Create-DNSArray 
        }
        elseif ($DClocation -like "LON*")
        {
          $DNSSuffixes = "lon.intensive.int,intensive.int,dfw.intensive.int,iad.intensive.int,ord.intensive.int,hkg.intensive.int,syd.intensive.int"
          $DNSSuffixes = Create-DNSArray  
        }
        elseif ($DClocation -like "HKG*")
        {
           $DNSSuffixes = "hkg.intensive.int,intensive.int,dfw.intensive.int,iad.intensive.int,ord.intensive.int,lon.intensive.int,syd.intensive.int"
           $DNSSuffixes = Create-DNSArray
        }
        elseif ($DClocation -like "SYD*")
        {
          $DNSSuffixes = "syd.intensive.int,intensive.int,dfw.intensive.int,iad.intensive.int,ord.intensive.int,lon.intensive.int,hkg.intensive.int" 
          $DNSSuffixes = Create-DNSArray
        }
        else
        {
         "no DC found"
        }
    }
    else
    {
    "custom"
    $DNSSuffixes = Create-DNSArray

  <#
        $DNSSuffixes = $DNSSuffixes -replace "\s",""
        #Convert the string of DNSservers to an array
        $DNSSuffixes = $DNSSuffixes.Split(",")
        $DNSsuffixes
        #>
 
    }



