#Author:Mark Wichall
#Date Updated: 19/11/2014

#Function used for Logging.
Function Get-CurrentRootPath
{
   $Path = Split-Path $script:MyInvocation.MyCommand.Path
   write-verbose $Path

    If ($Path -like "*:*")
    {
        $RootPath = $Path.Split(":")[0] + ":"
    }

    If ($Path -notlike "*:*")
    {
        $FolderArr = $Path.Split("\")
    
        #Loop through our folder array removing the 2 first blank entries  
        $Arr = 2
        $NewFolderArr = @()
        $CurrentFolder = "\"
        $TestArr = @()
        do
        {
             $CurrentFolder = $CurrentFolder + "\" + $FolderArr[$Arr] 
             $TestArr += $CurrentFolder
             $Arr ++
        }
        until ($Arr -eq  $FolderArr.Count)

        ForEach ($TestPath in $TestArr)
        {
            IF (Test-Path "$TestPath\powershell_root.txt")
            {
                $RootPath = $TestPath
                break
            }
        }

    }
    
    $Global:RootPath = $RootPath
    write-verbose "$Global:RootPath"
}

#Run function to find current path to logging code. 
Get-CurrentRootPath

#Sets logging to dev mode/disabled.
#$Global:Dev = $true

#Check if server is part of a cluster, quit if not.
Function Select-Cluster () {

$Services = Get-WmiObject -Class Win32_SystemServices -ComputerName  $env:COMPUTERNAME
If ($Services | select PartComponent | where {$_ -like "*ClusSvc*"})
{
    $Cluster = $true;Write-Host "This server is part of a Cluster." -ForegroundColor Green
}
Else
{
    $Cluster = $false; Write-Host "This server is not clustered. Quiting." -ForegroundColor Red
    Break
}
}

# Gets list of possible owners
Function Get-ClusterPossibleOwners ($ClusterGroups,$ClusterNodes) {

if (!$ClusterGroups)
{
    Import-module failoverclusters
    $ClusterGroups = Get-ClusterGroup
}

if (!$ClusterNodes)
{
    Import-module failoverclusters
    $ClusterNodes = Get-ClusterNode
}

[Array]$PossibleOwnersByGroup  = $null

$NodeCount = $ClusterNodes | measure-object | select-object Count 

foreach ($Clustergroup in $Clustergroups)
{   
    
    $PossibleOwner = $Null
    $PossibleOwner = New-Object PSObject
    
    [Array]$ClusterNodes = Get-ClusterNode
    [system.collections.arraylist]$ResultantOwners = $Null
    $ResultantOwners = $ClusterNodes

    $ResourceOwners = $Null
    $ResourceOwners = $Clustergroup | Get-ClusterResource | Get-ClusterOwnerNode
   
    foreach ($ResourceOwner in $ResourceOwners)
    {  
        $OwnerNodes = $NULL
        
        [Array]$OwnerNodes = $ResourceOwner.OwnerNodes

        $Compare = $Null
        $Compare = compare-object -ReferenceObject $ClusterNodes -DifferenceObject $OwnerNodes

        foreach ($Node in $Compare)
        {
            $ResultantOwners.remove($Node.inputobject)
        }
    }

    #$PossibleOwnersByGroup | Add-Member -type NoteProperty -Name $Clustergroup -Value $ResultantOwners.name
    $PossibleOwner | Add-Member -type NoteProperty -Name "ClusterGroup" -Value $Clustergroup
    $PossibleOwner | Add-Member -type NoteProperty -Name "PossibleOwners" -Value $ResultantOwners.name

    $OwnerCount = $ResultantOwners.name | measure-object | select-object Count 

    If ($NodeCount.count -eq $OwnerCount.count)
    {
        $PossibleOwner | Add-Member -type NoteProperty -Name "CanBeOwnedByAllNodes" -Value $true
    }
    Else
    {
        $PossibleOwner | Add-Member -type NoteProperty -Name "CanBeOwnedByAllNodes" -Value $false
    }
    
    $PossibleOwnersByGroup = $PossibleOwnersByGroup + $PossibleOwner
}
Return $PossibleOwnersByGroup
}

# Gets list of preferred owners.
Function Get-ClusterPreferredOwners () {

[Array]$PreferredOwners = $null
$clustergroups = Get-ClusterGroup | Where-Object {$_.IsCoreGroup -eq $false}
foreach ($clustergroup in $clustergroups)
{
    $ClusterGroupPSO = New-Object PSObject
    $CurrentOwner = $clustergroup.OwnerNode.Name
    $POCount = (($clustergroup | Get-ClusterOwnerNode).OwnerNodes).Count

    $ClusterGroupPSO | Add-Member -type NoteProperty -Name "ClusterGroup" -Value $Clustergroup
    
    if ($POCount -ne 0)
    {
        $PreferredOwner = ($clustergroup | Get-ClusterOwnerNode).Ownernodes.Name
        $ClusterGroupPSO | Add-Member -type NoteProperty -Name "CurrentOwner" -Value $CurrentOwner
        $ClusterGroupPSO | Add-Member -type NoteProperty -Name "PreferredOwner" -Value $PreferredOwner
        $ClusterGroupPSO | Add-Member -type NoteProperty -Name "PreferredOwnerSet" -Value $True   
    }
    else
    {
        $ClusterGroupPSO | Add-Member -type NoteProperty -Name "CurrentOwner" -Value $CurrentOwner
        $ClusterGroupPSO | Add-Member -type NoteProperty -Name "PreferredOwner" -Value "No Preferred Owner"
        $ClusterGroupPSO | Add-Member -type NoteProperty -Name "PreferredOwnerSet" -Value $False
    }
    $PreferredOwners = $PreferredOwners + $ClusterGroupPSO
}
Return $PreferredOwners
}

#Generate cluster commands and output to text file.
Function Get-ClusterCommands ($PreferredOwners,$PossibleOwnersByGroup) {

Import-module failoverclusters
$ClusterGroups = Get-ClusterGroup
$ClusterNodes = Get-ClusterNode
$Cluster = Get-Cluster
$ClusterDependency = Get-ClusterGroup | Get-ClusterResource | Get-ClusterResourceDependency

[Array]$ClusterCommands = $Null

$Date = Get-Date
$ClusterCommands = $ClusterCommands + "Generated Date: $Date"
$ClusterCommands = $ClusterCommands + " "

$ClusterCommands = $ClusterCommands + "-----------------------------------------------"
$ClusterCommands = $ClusterCommands + "### Cluster Information for cluster $Cluster"
$ClusterCommands = $ClusterCommands + "-----------------------------------------------"
$ClusterCommands = $ClusterCommands + " "

$ClusterCommands = $ClusterCommands + "Cluster Nodes:"
$ClusterCommands = $ClusterCommands + $ClusterNodes | FT -AutoSize    

$ClusterCommands = $ClusterCommands + "Cluster Groups:"
$ClusterCommands = $ClusterCommands + $ClusterGroups | FT -AutoSize

#Check if there are possible owners definded on any cluster group.
$Simple = $True
foreach ($ClusterGroup in $PossibleOwnersByGroup)
{
    if (!$ClusterGroup.CanBeOwnedByAllNodes)
    {
        $Simple = $false
    }
}

#Test not eq, -eq true worked.
If ($Simple)
{
$ClusterCommands = $ClusterCommands + " "
$ClusterCommands = $ClusterCommands + "#Possible Owners not definined. "
$ClusterCommands = $ClusterCommands + " "
}
else
{
$ClusterCommands = $ClusterCommands + " "
$ClusterCommands = $ClusterCommands + "#Possible Owners are configured."
$ClusterCommands = $ClusterCommands + " "
}

$ClusterCommands = $ClusterCommands + "Cluster Group Possible Owners"
$ClusterCommands = $ClusterCommands + "(This is calculated by looking at the possible owners of each resource):"
$ClusterCommands = $ClusterCommands + $PossibleOwnersByGroup | FT -AutoSize

$ClusterCommands = $ClusterCommands + "Cluster Resource Preferred Owners:"
#$ClusterCommands = $ClusterCommands + $PreferredOwners | Select-Object ClusterGroup, CurrentOwner,PreferredOwner | FT -AutoSize
$ClusterCommands = $ClusterCommands + $PreferredOwners | FT -AutoSize

$ClusterCommands = $ClusterCommands + "Cluster Resource Dependencies:"
$ClusterCommands = $ClusterCommands + $ClusterDependency | FT -AutoSize

$ClusterCommands = $ClusterCommands + "----------------------------------------------------------"
$ClusterCommands = $ClusterCommands + "### Generated Cluster Commands for cluster $Cluster"
$ClusterCommands = $ClusterCommands + "----------------------------------------------------------"
$ClusterCommands = $ClusterCommands + " "

$ClusterCommands = $ClusterCommands + "#----Move All Cluster Groups------------------------------------"
$ClusterCommands = $ClusterCommands + " "

#Test not eq, -eq true worked.
#No possible owners are defininded.
If ($Simple)
{   
    $ClusterCommands = $ClusterCommands + "## Cluster Commands to move All cluster groups To the specificed node:"

    ForEach ($ClusterNode in $ClusterNodes)
    {    
        $ClusterCommands = $ClusterCommands + " "
        $ClusterCommands = $ClusterCommands + "# Move all cluster groups to Node: $ClusterNode"    
        $ClusterCommands = $ClusterCommands + "Import-module failoverclusters"
        $ClusterCommands = $ClusterCommands + "Get-ClusterGroup | Move-ClusterGroup -Node `"$ClusterNode`" "
    }
}
#Possible owners are configured.
Else
{
    $ClusterCommands = $ClusterCommands + "#As possible owners are configured this set of commands is not applicable."
}

$ClusterCommands = $ClusterCommands + " "
$ClusterCommands = $ClusterCommands + "## Cluster Commands to move All cluster groups Off a specific node:"

ForEach ($ClusterNode in $ClusterNodes)
{
    $ClusterCommands = $ClusterCommands + " "
    $ClusterCommands = $ClusterCommands + "# Move all cluster groups off Node: $ClusterNode"    
    $ClusterCommands = $ClusterCommands + "Import-module failoverclusters"
    $ClusterCommands = $ClusterCommands + "Get-ClusterNode `"$ClusterNode`" | Get-ClusterGroup | Move-ClusterGroup"
}

$ClusterCommands = $ClusterCommands + " "
$ClusterCommands = $ClusterCommands + "#----Move Each Cluster Group------------------------------------"
$ClusterCommands = $ClusterCommands + " "

$ClusterCommands = $ClusterCommands + "## Cluster Commands to move Each cluster group to the specified node"

#cycle through possibleowners
ForEach ($ClusterNode in $ClusterNodes)
{
    $ClusterCommands = $ClusterCommands + " "
    $ClusterCommands = $ClusterCommands + "# Move each cluster groups to Node: $ClusterNode"
    $ClusterCommands = $ClusterCommands + "Import-module failoverclusters"

    [Array]$ClusterCommandsEnd = $Null

    foreach ($ClusterGroup in $PossibleOwnersByGroup)
    {
        $LoopState = $Null
        
        foreach ($Node in $ClusterGroup.PossibleOwners)
        {
            if ($Node -eq $ClusterNode)
            {
                $LoopState = $true
                $ClusterCommands = $ClusterCommands + "Move-ClusterGroup `"$($ClusterGroup.ClusterGroup)`" -Node `"$ClusterNode`" "
            } 
        }
        If ($LoopState -ne $true)
        {
            $ClusterCommandsEnd = $ClusterCommandsEnd + "#  Cluster Group: `"$($ClusterGroup.ClusterGroup)`" Cannot be moved to Node: `"$ClusterNode`" As it can't be owned by this server, see possible owners."
        }
    
    }
    $ClusterCommands = $ClusterCommands + $ClusterCommandsEnd 
}

$ClusterCommands = $ClusterCommands + " "
$ClusterCommands = $ClusterCommands + "#----Move Each Cluster Group to it's Prefered Owner------------------------------------"

$ClusterCommands = $ClusterCommands + " "
$ClusterCommands = $ClusterCommands + "## Cluster Commands to move each cluster group to there preferred owner"
$ClusterCommands = $ClusterCommands + " "

[Switch]$AnyPOSet = $false
ForEach ($PreferredOwner in $PreferredOwners)
{
    if ($PreferredOwner.PreferredOwnerSet)
    {
    $AnyPOSet = $true
    }
}

If ($AnyPOSet)
{

    $ClusterCommands = $ClusterCommands + "Import-module failoverclusters"

    [Array]$ClusterCommandsEnd = $Null
    #cycle through prefered owners 
    ForEach ($PreferredOwner in $PreferredOwners)
    {
        If ($($PreferredOwner.PreferredOwnerSet))
        {
            $ClusterCommands = $ClusterCommands + "Move-ClusterGroup `"$($PreferredOwner.ClusterGroup)`" -Node `"$($PreferredOwner.PreferredOwner[0])`" "
        }
        Else
        { 
            $ClusterCommandsEnd = $ClusterCommandsEnd + "#  Cluster Group: `"$($PreferredOwner.ClusterGroup)`" has no prefered owners."
        }
    }
    $ClusterCommands = $ClusterCommands + $ClusterCommandsEnd

}
Else
{
    $ClusterCommands = $ClusterCommands + "#As prefered owners are not configured this set of commands is not applicable."
}

$Verbs = "Stop","Start"

ForEach ($Verb in $Verbs)
{
    $ClusterCommands = $ClusterCommands + " "
    $ClusterCommands = $ClusterCommands + "#----$Verb Each Cluster Group----------------------------------"

    $ClusterCommands = $ClusterCommands + " "
    $ClusterCommands = $ClusterCommands + "# Cluster Commands to $Verb each cluster group"
    $ClusterCommands = $ClusterCommands + "Import-module failoverclusters"
    ForEach ($ClusterGroup in $ClusterGroups)
    {
        $ClusterCommands = $ClusterCommands + "$Verb-ClusterGroup `"$ClusterGroup`" "      
    }
}

$Verbs = "Stop","Start"

ForEach ($Verb in $Verbs)
{
    $ClusterCommands = $ClusterCommands + " "
    $ClusterCommands = $ClusterCommands + "#----$Verb Each Cluster Resource--------------------------------"
            
    $ClusterCommands = $ClusterCommands + " "
    $ClusterCommands = $ClusterCommands + "# Cluster Commands to $Verb each cluster resource"
    $ClusterCommands = $ClusterCommands + "Import-module failoverclusters"
    ForEach ($ClusterGroup in $ClusterGroups)
    {
        $ClusterCommands = $ClusterCommands + " "
        $ClusterCommands = $ClusterCommands + "# Cluster Commands to $Verb each cluster resource in cluster group $ClusterGroup"
   
        $ClusterResources = $ClusterGroup | Get-ClusterResource
        
        If (!$ClusterResources)
        {
            $ClusterCommands = $ClusterCommands + "# No Resources in Cluster Group: $ClusterGroup "
        }
        Else
        {
            ForEach ($ClusterResource in $ClusterResources)
            {
                $ClusterCommands = $ClusterCommands + "$Verb-ClusterResource `"$ClusterResource`" "
            }
        }
    }
}

$ClusterCommands = $ClusterCommands + " "
$ClusterCommands = $ClusterCommands + "#---------------------------------------------------------------"
$ClusterCommands = $ClusterCommands + " "

$ClusterCommands = $ClusterCommands + "## Useful Generic Cluster Commands:"
$ClusterCommands = $ClusterCommands + " "

$ClusterCommands = $ClusterCommands + "# Cluster Name"
$ClusterCommands = $ClusterCommands + "Import-module failoverclusters"
$ClusterCommands = $ClusterCommands + "Get-Cluster"
$ClusterCommands = $ClusterCommands + " "

$ClusterCommands = $ClusterCommands + "# List Cluster Groups"
$ClusterCommands = $ClusterCommands + "Import-module failoverclusters"
$ClusterCommands = $ClusterCommands + "Get-ClusterGroup"
$ClusterCommands = $ClusterCommands + " "

$ClusterCommands = $ClusterCommands + "# List Cluster Nodes"
$ClusterCommands = $ClusterCommands + "Import-module failoverclusters"
$ClusterCommands = $ClusterCommands + "Get-ClusterNode"
$ClusterCommands = $ClusterCommands + " "

$ClusterCommands = $ClusterCommands + "# List Cluster Resource Possible Owners"
$ClusterCommands = $ClusterCommands + "Import-module failoverclusters"
$ClusterCommands = $ClusterCommands + "Get-ClusterGroup | Get-ClusterResource | Get-ClusterOwnerNode"
$ClusterCommands = $ClusterCommands + " "

$Char = [char]36
$ClusterCommands = $ClusterCommands + "#Move all cluster groups from the node you run this from, cluster determins destination"
$ClusterCommands = $ClusterCommands + "#Note: This is prone to error.  If it's run on the wrong server it will move resource off that server"
$ClusterCommands = $ClusterCommands + "Get-ClusterNode " + $Char + "env:COMPUTERNAME | Get-ClusterGroup | Move-ClusterGroup"
$ClusterCommands = $ClusterCommands + " "

Return $ClusterCommands
}

#Run functions

#Check if it's a server thats part of a cluster. 
Select-Cluster

$PossibleOwnersByGroup = $Null
$PreferredOwners = $Null
$ClusterCommands = $Null

Import-module failoverclusters
$ClusterGroups = Get-ClusterGroup
$ClusterNodes = Get-ClusterNode

$PossibleOwnersByGroup = Get-ClusterPossibleOwners -ClusterGroups $ClusterGroups -ClusterNodes $ClusterNodes

$PreferredOwners = Get-ClusterPreferredOwners

$ClusterCommands = Get-ClusterCommands -PreferredOwners $PreferredOwners -PossibleOwnersByGroup $PossibleOwnersByGroup

#function output check file exists.

#Old output methord.
#Output commands to text file
#$FilePathTxt = "C:\rs-pkgs\ClusterCommands.txt"
#$ClusterCommands | Out-File -filepath $FilePathTxt
#Write-Host "Cluster Commands outputted to file: $FilePathTxt " -ForegroundColor Green
#Invoke-Item $FilePathTxt

#Output to log share
Import-module failoverclusters
$Cluster = Get-Cluster
$Date = (Get-Date -format "ddMMyyyy-HHmmss")
$FilePathTxt = "$Global:RootPath\Logs\ClusterCommandGenerator\" + $Cluster + "_" + $Date + ".txt" 
$ClusterCommands | Out-File -filepath $FilePathTxt

#open file
#Invoke-expression "notepad $FilePathTxt"
Invoke-Item $FilePathTxt

$WriteOut = "`nCluster Commands outputted to file:`n $Global:RootPath\Logs\ClusterCommandGenerator\" + $Cluster + "_" + $Date + ".txt"
Write-Host $WriteOut  -ForegroundColor Green

#Log to master log file
Try
{
    Import-Module "$Global:RootPath\Shared_Modules\Logging_Module.psm1" -EA SilentlyContinue
    Write-MasterLogFile -functionname "Get-ClusterCommands" -scriptname "ClusterCommandGenerator" -Notes "" -Account ""
}
Catch
{
    #Do nothing
}

<# Run line:
PowerShell -ExecutionPolicy Bypass  -nologo -command {`
$path = "\\media.lon.rackspace.com\UploadBuffer\PowerShell";
$script = ".\ClusterCommandGenerator\ClusterCommandGenerator.ps1";
Function Get-Username {$username = Read-host "Enter intensive username" ;return $username};$username = Get-Username;`
net use $path /user:Intensive\$username | out-null;`
CD $path;Invoke-Expression $script; net use $path /d /y | Out-Null;}
#>