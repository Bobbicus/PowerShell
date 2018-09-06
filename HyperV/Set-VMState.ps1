<#
    .SYNOPSIS
    Get the orginal running state of VMs, compare this to the running state at the end of maintenance or 
    other work. 
       
    .DESCRIPTION
    Full description: Get the orginal running state of VMs, compare this to the running state at the end of maintenance or 
    other work.  Set VM state to match original running state.
    supported: Yes
    keywords: State,Maintenance,Start,Stop
    Prerequisites: Yes/No
    Makes changes: Yes
    Changes Made:
        Starts VMs to match original running state
        Shutdown VMs to match original running state

    Download File: N/A
    .PARAMETER <Name of parameter>
    Description: <Description of parameter>
    Prompt: <The text of the user prompt>
    Example use: <example command>
    Default: None
    .EXAMPLE
    Full command: <example command>
    Description: <description of what the command does>
    Output: <List output>
       
    .OUTPUTS
    LastWriteTime                           Name                                   
    -------------                           ----                                   
    31/05/2017 11:20:51                     VMstatesBeginning.csv                  


    Winjas-DB2 Running
    Winjas-OM1 Running
    Winjas-VMM2 Running
    AG DB1 Running
    AG DB2 Running
    Winjas-DB1 Running
    Winjas-VMM1 Running
    Winjas-GW1 Running
    Winjas-MGMT1 Running
    
    Previous State
    DiogoWinSrv2016 Running
    Starting VmWeb1 that was previoulsy in running stat
        
    .NOTES
    Minimum OS: 2012 R2
    Minimum PoSh: 3.0
    Version Table:
    Version :: Author             :: Live Date   :: JIRA     :: QC          :: Description
    -----------------------------------------------------------------------------------------------------------
    1.0     :: Bob Larkin :: 07-JUN-2017 :: MC-111 :: Joe Bloggs  :: Release
#>

#Function retirves the state of the VMs and saves them in a VMstatesBeginning.csv to be referenced later
function Get-VMBaselineState
{
    Try
    {
        $clusterNodes = Get-ClusterNode;
        $VMList  = ForEach($item in $clusterNodes){
            Get-VM -ComputerName $item.Name | Select-Object Name,State 
        }
        $VMStateBeginning = $VMList | Export-Csv C:\rs-pkgs\VMstatesBeginning.csv
        Write-Host  "New csv created" -ForegroundColor Green
    
        $StartState = Import-Csv C:\rs-pkgs\VMstatesBeginning.csv
        $StartState
        #Get VM state at start of a maintenance and compare the two to see if there is any drift.
        #$VMStateBeginning = Get-VM | Select-Object Name,State | Export-Csv C:\rs-pkgs\VMstatesBeginning.csv
        #Write-Host  "New csv created" -ForegroundColor Green
        #Get-ChildItem C:\rs-pkgs\VMstatesBeginning.csv| Select-Object LastWriteTime,Name
        Get-Menu 
    }
    Catch
    {
        Return "ERROR : Unhandled exception :: (Line: $($_.InvocationInfo.ScriptLineNumber) Line: $($_.InvocationInfo.Line) Error message: $($_.exception.message))"
    }
}

             
#Function retrieves the state of the VMs and saves them in a VMstatesEnd.csv to compare to VMstatesBeginning.csv
function Get-VMCurrentState
{
    Try
    {
        Write-Host  "Comparing current state to:" -ForegroundColor Green
        Get-ChildItem C:\rs-pkgs\VMstatesBeginning.csv| Select-Object LastWriteTime,Name
        Write-Host  "`n"
        #Get VM state at end of a maintenance and compare the two to see if there is any drift.
        $clusterNodes = Get-ClusterNode;
        $VMList  = ForEach($item in $clusterNodes){
            Get-VM -ComputerName $item.Name | Select-Object Name,State 
        }

        #Export the state of the CSV to VMstatesEnd.csv
        $VMStatesEnd = $VMList | Export-Csv C:\rs-pkgs\VMstatesEnd.csv
        #Retreive the contents of the two csv files containing running state at start and end of Maint
        $StartState = Import-Csv C:\rs-pkgs\VMstatesBeginning.csv
        $PreviousVMState = Import-Csv C:\rs-pkgs\VMstatesEnd.csv
        #Compare the two csvs for differences and display the results
        $CompareState = Compare-Object -ReferenceObject $StartState -DifferenceObject $PreviousVMState -Property State,Name -IncludeEqual
        $VMStateResults = foreach ($VM in $CompareState)

        {
            if ($VM.SideIndicator -eq "=>")
            {
            Write-Host "Current State"
            Write-host $VM.Name,$VM.State -ForegroundColor Red
            }
            if ($VM.SideIndicator -eq "<=")
            {
            Write-Host "Previous State"
            Write-host $VM.Name,$VM.State -ForegroundColor Red
            }
            if ($VM.SideIndicator -eq "==")
            {
            Write-host $VM.Name,$VM.State -ForegroundColor Green
            }

    }
    Get-Menu 
    }
    Catch
    {
        Return "ERROR : Unhandled exception :: (Line: $($_.InvocationInfo.ScriptLineNumber) Line: $($_.InvocationInfo.Line) Error message: $($_.exception.message))"
    }
}


function Set-VMRunningState
{
    Try
    {
        Write-Host  "Comparing current state to:" -ForegroundColor Green
        Get-ChildItem C:\rs-pkgs\VMstatesBeginning.csv| Select-Object LastWriteTime,Name
        Write-Host  "`n"
        #Get VM state at end of a maintenance and compare the two to see if there is any drift.
        $clusterNodes = Get-ClusterNode;
        $VMList  = ForEach($item in $clusterNodes){
            Get-VM -ComputerName $item.Name | Select-Object Name,State 
        }
        #Export the state of the CSV to VMstatesEnd.csv
        $VMStatesEnd = $VMList | Export-Csv C:\rs-pkgs\VMstatesEnd.csv
        #Retreive the contents of the two csv files containing running state at start and end of Maint
        $StartState = Import-Csv C:\rs-pkgs\VMstatesBeginning.csv
        $PreviousVMState = Import-Csv C:\rs-pkgs\VMstatesEnd.csv
        #Compare the two csvs for differences and display the results
        $CompareState = Compare-Object -ReferenceObject $StartState -DifferenceObject $PreviousVMState -Property State,Name -IncludeEqual
        $VMCollection = @()
    
        $VMStateResults = foreach ($VM in $CompareState) {
            #Get previous state and check if it was running or off and start or stop the VM as required
            if ($VM.SideIndicator -eq "<=")
            {
            $item = New-Object PSObject
            $item | Add-member -MemberType NoteProperty -Name "Name" -Value $VM.name
            $item | Add-member -MemberType NoteProperty -Name "State" -Value $VM.State
            $VMCollection +=$item
            Write-Host "Previous State"
            Write-host $VM.Name,$VM.State -ForegroundColor Red
            $VMObj = $VM.Name
                if($VM.State -eq "Off"){
                Write-Host "Stopping $VM.Name that was previouslly in Off state"
                Stop-VM -Name $VM.Name
                }  
                if($VM.State -eq "Running"){
                Write-Host "Starting $VM.Name that was previoulsy in running state"
                Start-VM -Name $VM.Name 
                }           
            }
            if ($VM.SideIndicator -eq "==")
            {
            Write-host $VM.Name,$VM.State -ForegroundColor Green
            }
        
        }
        #return $VMCollection
        Get-Menu 
    }
    Catch
    {
        Return "ERROR : Unhandled exception :: (Line: $($_.InvocationInfo.ScriptLineNumber) Line: $($_.InvocationInfo.Line) Error message: $($_.exception.message))"
    }
    
    
}


function Get-Menu 
{
    Try
    {

        #Get user input to check intial state, end state of VM and return VMs to original state
        Write-Host  "1. Take baseline of VMs Running State" -ForegroundColor Cyan
        Write-Host  "2. Compare currnet VM running state to previous baseline" -ForegroundColor Cyan
        Write-Host  "3. Set VM running state to match baseline" -ForegroundColor Cyan
        Write-Host  "4. Enter 4 or Q to quit" -ForegroundColor Cyan

        $UserInput = read-host "Choose from taking baseline or comparing current state to baseline 1, 2 or 3"


        If ($UserInput -eq 1)
        {
            Get-VMBaselineState
        }
        If ($UserInput -eq 2)
        {
            Get-VMCurrentState
        }
        If ($UserInput -eq 3)
        {
            Set-VMRunningState
        }
        If ($UserInput -eq 4 -or $UserInput -eq "Q")
        {
            Break
        }
    }
    Catch
    {
        Return "ERROR : Unhandled exception :: (Line: $($_.InvocationInfo.ScriptLineNumber) Line: $($_.InvocationInfo.Line) Error message: $($_.exception.message))"
    }

}

Get-Menu