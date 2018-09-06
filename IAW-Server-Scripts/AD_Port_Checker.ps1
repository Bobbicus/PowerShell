#v0.1 - Initial build
$version = "0.1"
$scriptname = "ADPortTester"

#Used to find root of folder for loading other code using powershell_root.txt
Function Get-CurrentRootPath
{
    $Path = Split-Path $script:MyInvocation.MyCommand.Path
     
    $FolderArr = $Path.Split("\") 
    $FolderCount = ($FolderArr.Count)

    do
    {
        $Path = $FolderArr[0..$FolderCount] -join "\"
        IF (Test-Path "$Path\powershell_root.txt")
        {
            $RootPath = $Path
            break
        }
        ELSE
        {
            $FolderCount = $FolderCount -1
        }
    }
    until ($FolderCount -lt 0)

    IF ($RootPath)
    {
        $Global:RootPath = $RootPath
        write-debug $Global:RootPath
    }
    ELSE
    {
        Write-Host "`nError - folder root not found.`n`n" -ForegroundColor Red
        Break;
    }
}
#Run function above
$Global:RootPath = $null
Get-CurrentRootPath

Function Import-CustomModule {

   Param (
   [Parameter()][string]$path,
   [Parameter()][string]$name,
   [Parameter()][switch]$builtin
   )

   If($builtin -eq $true)
   {
        Import-Module $name
    }
    ELSE
    {
        
        IF(Test-Path $path)
        {
            Import-Module $path -DisableNameChecking -Force
        }
        Else
        {
            write-host "unable to find $path. Script quit" -ForegroundColor Red
            break
        }
    }
    
    $LoadedModules = Get-Module
    ForEach ($modulename in $LoadedModules)
    {
       IF ($modulename.name -like $name)
        {
            $loaded = $true
        }
    }

    If($loaded -ne $true)
    {
        write-host "Unable to load $name module. Script quitting" -ForegroundColor Red
        break
    }

}

#Import modules we will need
Import-CustomModule "$Global:RootPath\Shared_Modules\Logging_Module.psm1" -Name "Logging_Module"
#No logging required so commenting out line below
IF($Global:LogCreated -ne $true ){New-LogFile -ScriptName "$scriptname" -Path "$Global:RootPath\"}

#Import QC_Module code as we use the Get-PublicNic function to get the DNS IP address
Import-CustomModule "$Global:RootPath\SQL_Installer_QC\QC_Module.psm1" -Name "QC_Module"

#Used to prompt user for DNS IP address
Import-CustomModule "$Global:RootPath\Shared_Modules\Questions_Module.psm1" -Name "Questions_Module"

#Get the adapter config
$PublicNic = Get-PublicNic -Quiet

#Set the DNS address
$FoundDNSAddress = $PublicNic.DNSServerSearchOrder[0]

#Prompt user for DNS server
$DNSAddress = Ask-Question -Question "Enter AD server IP address (For DNS address from Public adapter just hit enter)" -Default $FoundDNSAddress -RegexMatch "^\b(?:\d{1,3}\.){3}\d{1,3}\b" -Regex

#Function for testing ports
Function Test-ADPorts
{
Param (
   [Parameter(Mandatory=$true)]$IP
   )

    $Ports = 389,53,88,445,3268,135,139,636,464
     
    ForEach ($Port in $Ports) 
    {
        $result = $NULL
        $result = Test-TCPPort -IP $IP -Port $Port
            
        If ($result)
        {
            Write-Host "TCP Port $Port on $IP is contactable from $ENV:COMPUTERNAME" -ForegroundColor Green
        }
        ELSE
        {
            Write-Host "TCP Port $Port on $IP is NOT contactable from $ENV:COMPUTERNAME!!" -ForegroundColor Red
        }
    }
}

<#
.Synopsis
   Short description
.DESCRIPTION
   Long description
.EXAMPLE
   Example of how to use this cmdlet
.OUTPUTS
   Output from this cmdlet (if any)
.NOTES
   General notes
#>
Function Test-TCPPort {
    
    Param
    (
        #IP of device being tested.
        [Parameter(Mandatory=$true,
                   Position=0)]
        [String]$IP,
        # Port to test.
        [Parameter(Mandatory=$true,
                   Position=1)]
        [Int]$Port,
        # Timeout Value for test
        [Parameter(Position=2)]
        [Int]$Timeout = 1000
    )
    
    [Switch]$PortTest = $Null
    
      $ticksPerMilliSecond = 10000
      $client = New-Object net.sockets.tcpclient
      $client.BeginConnect($IP,$port,$null,$null) > $null
      if ($client.Connected) {$client.Close();return $true}
      $startTimeout = Get-Date
      while ((Get-Date).Ticks - $startTimeout.Ticks -le $timeout * $ticksPerMilliSecond)
      {
        if ($client.Connected) 
        {
          $client.Close()
  	      return $true
        }
      }
      $client.Close()
      return $false
}

#Test ports and output to screen
Test-ADPorts -IP $DNSAddress

#Call home to appstats
New-AppStatsFile -scriptname $scriptname -device $env:COMPUTERNAME -version $version