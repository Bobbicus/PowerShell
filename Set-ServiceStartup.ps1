<#
    .SYNOPSIS
     Set start mode on a Service
     
    .DESCRIPTION
    Full description: Set startup type on a Service
    WHAM - supported: Yes
    WHAM - keywords: Service, StartMode, startup
    WHAM - Prerequisites: No
    WHAM - Makes changes: Yes
    WHAM - Column Header: Set Service startup type

     
    .PARAMETER ServiceName
    Description: Name of service
    WHAM Prompt: Enter the name of the Service  (example: RemoteRegistry, Spooler)
    Example use: 
    
    .Parameter StartMode
    Description: Start mode to set
    WHAM Prompt: Enter the Start-up type for the service (example: auto, manual, disabled)
    Example use: 
    
    .PARAMETER force
    Description: Supresses all user confirmation from script
    Example use: Disable-User -UserName testuser
    Type: Switch
    Default: None

    
    .EXAMPLE
    Full command: Set-RegistryKey -Path "HKLM:\Some\Key\Here" -Value "NewValue" -Type "string"
    Description: Set value of registry key
  
    .NOTES
    Author: Bob Larkin
    Minimum OS: 2008 R2
    Minimum PoSh: 2.0
    Date: 02/09/2015
    Version: 1.01
    Approved by: 
#>
function Set-ServiceStartup
{
    Param(
    [Parameter(Mandatory=$true)]$ServiceName,
    [Parameter(Mandatory=$true)]$StartMode,
    [switch]$force
    )
    
    #Requires -version 2.0

    #Skip the user validation if the force parameter is used
    if (-not $force)
    {
        #Confirm the user they want to make changes
        if((Read-Host "Warning, you are about set the startup typ of $ServiceName with the value $StartMode, are you sure you wish to continue? (Y/N)") -notlike "y*")
        {
            exit
        }
    }

    Try
    {

        Set-Service $ServiceName -startupType $StartMode
        $ServiceStartMode = Get-WmiObject Win32_Service | Select-Object DisplayName,Name,State,StartMode | Where-Object {($_.Name -eq $ServiceName)}
        
        $output = New-Object PSObject -Property @{ 
            "Service Display Name" = $ServiceStartMode.DisplayName
            "Service Name" =  $ServiceName
            "Service Status" = $ServiceStartMode.Status
            "Service Startup type" = $ServiceStartMode.StartMode

        }
       
        
        #Confirm success
        Return $Output
    }
    Catch
    {
        Return "An unexpected error has occured"
    }
}