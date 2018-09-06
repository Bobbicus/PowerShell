<#
    .SYNOPSIS
    Check VMs preferred nodes against current owner
    
    .DESCRIPTION
    Full description: Checks the current owner and preferred owner of a Hyper-V VM
    WHAM - supported: Yes
    WHAM - keywords: VM,MPC,Preferred,Owner
    WHAM - Prerequisites: No
    WHAM - Makes changes: No
    WHAM - Column Header: Check VM preferred owner
                 
    .EXAMPLE 
    Full command: Get-VMOwnerNode
    Output: true/false
    
    .PARAMETER Force
    Description: Supresses all user confirmation from script
    Example use: Move-VMOwnerNode -Force
    Type: String
    Default: None

    .NOTES
    Author: Bob Larkin
    Modified: 
    Minimum OS: 2012
    Minimum PoSh: 3.0
    Date: 24/02/2017
    Version: 3.0
    Approved by: 
#>


Function Get-VMOwnerNode
{
$GetClusGroups = Get-ClusterGroup
            #Exlude non VM cluster groups
            $VMMatch  = $GetClusGroups  | Where {$_.Name -ne "Cluster Group" -and $_.Name -ne "Available Storage"}
            #Loop through the VMs and see if the current owner matches the preferred owner 
            #Displays if no preferred owner is set
            $VMCount = 0 
            foreach ($VM in $VMMatch)
            {

                    $PrefOwner = Get-ClusterOwnerNode -Group $VM.Name
                    $PrefOwnerNode = $PrefOwner.OwnerNodes
                    $VMCurrentOwner =  $VM.OwnerNode

                    if (-not $PrefOwner.OwnerNodes)
                    {
                        Write-Host "$VM `nNo preferred owner set `n" -ForegroundColor Yellow
                    }
                    if($PrefOwner.OwnerNodes)
                    {
                    $CompareOwner = Compare-Object $VMCurrentOwner $PrefOwnerNode
                        if ($CompareOwner)
                        {
                            Write-host "$VM `nNot on preferred owner `n " -ForegroundColor red
                            Write-host $VMCurrentOwner
                            Write-host $PrefOwnerNode 
                            $VMCount +1

                        }
                        if (!$CompareOwner)
                        {
                            Write-host "$VM `nOn preferred owner `n" -ForegroundColor Green
                            Write-host $VMCurrentOwner
                            Write-host $PrefOwnerNode 
                        }
                       
              
                    } 
                     
            } 

}