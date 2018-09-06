<#
    .SYNOPSIS
    Check VMs are on preferred nodes and moves them if 
    
    .DESCRIPTION
    Full description: Checks the current owner and preferred owner of a Hyper-V VM and moves it to preferred owner
    WHAM - supported: Yes
    WHAM - keywords: VM,MPC, Preferred, Owner
    WHAM - Prerequisites: No
    WHAM - Makes changes: Yes
    WHAM - Column Header: Move VM to preferred owner
                 
    .EXAMPLE 
    Full command: Move-VMOwnerNode
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
#region Event Logger


################################################
# Rackspace event logger
#
# Author: Bob Larkin
# 
#
# version 1.1 - release
#
#  Server version  | Tested  |
#    --------------------------
#    Server 2003 x32 |    ?    |
#    Server 2003 x64 |    ?    |
#    Server 2008 x32 |    N    |
#    Server 2008 x64 |    N    |
#    Server 2008 R2  |    Y    |
#    Server 2012     |    Y    |
#    Server 2012 R2  |    Y    |
#
# PowerShell version:
#requires -version 2.0
# OS Version:
# Windows 2012 R2
################################################
#
################################################
<#
.Synopsis
This Powershell module will update the Windows event log.
.Description
The script will update the Windows event log with changes made from users scripts. 
Informational Messages will be logged as Event ID: 101
Error Messages will be logged as Event ID: 102

.Example


Three Stages to Log infomration to the Log

1)Create an array New-RSEventLog

2)Store all cahnges/infomration to an array to be written to the log in the ende..

Update-RSEventInfo -AddtoLog "This is line one of the event log message"
Update-RSEventInfo -AddtoLog "This will be line two"

3)At the end of the script you write the data in the array to the application log

#Update event log with an Error message with Event ID 102
Write-RSEventLog -EventLogInformation "$EventMessage" -Type Error

#Update event log with an Information message with Event ID 101
Write-RSEventLog -EventLogInformation "$EventMessage" -Type Info

.Notes
Automatically writes the script name and username to array to be added to the event log


Full example

New-RSEventLog


Update-RSEventInfo -AddtoLog "This is line one of the event log message"
Update-RSEventInfo -AddtoLog "This will be line two"
Update-RSEventInfo -AddtoLog "This will be line three"
$EventMessage = $LogArray | out-string

Write-RSEventLog -EventLogInformation "$EventMessage" -Type Error

#>


function Write-RSEventLog
{
Param (
    [Parameter()]$EventLogInformation = (Read-Host "Enter Stuff"),
    #[Parameter()]$EvID = (Read-Host "Enter Stuff"),
    #[Parameter()][Switch]$ErrorMsg,
    #[Parameter()][Switch]$Info
    [Parameter()][ValidateSet(“Error”,“Info”)][string] $Type = “Info”
       )

$RSEventLog = [System.Diagnostics.EventLog]::SourceExists("RS Powershell Script")

    if (-not $RSEventLog)
    { 
     switch ($Type)
    {
    "Error" {$RSEventID = 112}
    "Info" {$RSEventID = 111}
    }

        New-EventLog -LogName Application –Source “RS Powershell Script” 
        Write-EventLog –LogName Application –Source “RS Powershell Script” –EntryType Information –EventID $RSEventID –Message $EventMessage 
    }
    else
    {
     switch ($Type)
    {
    "Error" {$RSEventID = 112}
    "Info" {$RSEventID = 111}
    }
        Write-EventLog –LogName Application –Source “RS Powershell Script” –EntryType Information –EventID $RSEventID –Message $EventMessage
    }
}

#Create an array to store the script changes.  
function New-RSEventLog
{
    [System.Collections.ArrayList]$Global:LogArray = @()

    $nl = [Environment]::NewLine
   

    #Write username to array for logging
    Update-RSEventInfo -AddtoLog "Username: $env:USERNAME $nl" 
    #Get the name of the current script from the call stack and write to array for logging
    $RSScriptName = $((Get-PSCallStack)[0].Command)
    Update-RSEventInfo -AddtoLog "Script Name: $RSScriptName $nl" 


}


#New-RSEventLog
#Function for adding to array 
function Update-RSEventInfo
{
    Param (
        [Parameter()]$AddtoLog = (Read-Host "Add to Array:")
        )
    #This will append a new line to each entry in the array to amke the log easier to use
    $nl = [Environment]::NewLine
    $AddtoLog2 = $AddtoLog + $nl
    $LogArray.Add($AddtoLog2)

}


#endregion

Function Move-VMOwnerNode
{
    Try
    {
        #get node status on cluster if any nodes are down do not try distirbute VMs 
        $Nodes = Get-clusternode
        foreach ($Node in $Nodes)
        {
            if ($node.State -eq "Up")    {
                Write-host "Node $Node is Up"
            }
            if ($node.State -eq "Down")
            {
                Write-host "Node $Node is Down exiting script without balancing nodes"
                exit
            }

        }
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
    
        
        
        Function Get-VMOwnerNode
        {
        $GetClusGroups = Get-ClusterGroup
                    #Exlude non VM cluster groups
                    $VMMatch  = $GetClusGroups  | Where {$_.Name -ne "Cluster Group" -and $_.Name -ne "Available Storage" -and $_.name -ne "835685-hyp-repl"}
                    #Loop through the VMs and see if the current owner matches the preferred owner 
                    #Displays if no preferred owner is set
                    $Script:VMCount = 0
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
                                    $Script:VMCount ++
                            
                                }
                                if (!$CompareOwner)
                                {
                                    Write-host "$VM `nOn preferred owner `n" -ForegroundColor Green
                                    Write-host $VMCurrentOwner
                                    Write-host $PrefOwnerNode 
                                }
                       
              
                            } 
                      
                    } 
        return $Script:VMCount

        }
        #Check if VMs are on preferred owner 
        Get-VMOwnerNode
        
        Function Set-VMPreferredOwner
        {
            #Get the cluster resource groups
            $GetClusGroups = Get-ClusterGroup
            #Exlude non VM cluster groups
            $VMMatch  = $GetClusGroups  | Where {$_.Name -ne "Cluster Group" -and $_.Name -ne "Available Storage"}
            #Loop through the VMs and see if the current owner matches the preferred owner 
            #Displays if no preferred owner is set
            foreach ($VM in $VMMatch)
            {

                    $PrefOwner = Get-ClusterOwnerNode -Group $VM.Name
                    $PrefOwnerNode = $PrefOwner.OwnerNodes
                    $VMCurrentOwner =  $VM.OwnerNode

                    if (-not $PrefOwner.OwnerNodes)
                    {
                        Write-Host "$VM No preferred owner set $VMCurrentOwner" -ForegroundColor Yellow
                    }
                    if($PrefOwner.OwnerNodes)
                    {
                    $CompareOwner = Compare-Object $VMCurrentOwner $PrefOwnerNode
                        if ($CompareOwner)
                        {
                            Write-host "Not on preferred owner" -ForegroundColor red
                            Write-host $VMCurrentOwner
                            Write-host $PrefOwnerNode 
                            
                            Write-host $VMCurrentOwner 
                            Write-host $PrefOwnerNode 
                           
                            $VMToMove = $VM.Name
                            $PrefOwnerStr = [string]$PrefOwnerNode
                            #This handles the preferred owner if there is more than one it splits the string and uses the first entry
                            $PrefOwnerSplit = $PrefOwnerStr.Split(" ")
                            $PrefOwner = $PrefOwnerSplit[0]
                            Write-host $VMToMove -ForegroundColor green
                            Write-host $PrefOwner -ForegroundColor green
                            Get-ClusterGroup -Name $VMToMove  | Move-ClusterGroup -node  $PrefOwner
                            

                        }
                        if (!$CompareOwner)
                        {
                            Write-host "On preferred owner" -ForegroundColor Green
                            Write-host $VMCurrentOwner
                            Write-host $PrefOwnerNode 
                        }
                       
              
                    } 
                     


            }

        }

            if ($VMCount -gt 0)
            {
            #Confirm VMs are on preferred owner 
            Set-VMPreferredOwner
            }
        }

    
    catch
    {
        Return $_ 
    }
    

}

Move-VMOwnerNode
