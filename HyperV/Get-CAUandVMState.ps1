<#
    .SYNOPSIS
    Check reason for Live migration failure
       
    .DESCRIPTION
    Check reason for Live migration failure.  Check if Live migration completed successfully since the alert and see if it is due to CAU
    supported: Yes
    keywords: Live, Migration, CAU
    Prerequisites: No
    Makes changes: No


    .EXAMPLE
    Full command: 
    Description: <description of what the command does>
    Output: 



    .OUTPUTS
    <List outputs>
        
    .NOTES
    Minimum OS: 2012 R2
    Minimum PoSh: 4
    Version Table:
    Version :: Author             :: Live Date   :: JIRA     :: QC          :: Description
    -----------------------------------------------------------------------------------------------------------
    1.0     :: Bob Larkin         :: 08-Dec-2017 :: N/A      ::             :: Release

#>


Try
{
$VMName = Read-Host "Enter Name of VM to check:"


#Check whether hypervisor is part of a cluster and carry out relevent logic depending on result

$clusterCheck = get-service ClusSvc -ErrorAction SilentlyContinue
if($clusterCheck -eq $null)
{
    Write-Host "The cluster service is not present. This diagnostic will be executed in standalone mode." -ForegroundColor Yellow -BackgroundColor Black
    $AlertState = "ClusterError"
    #Get the state of the VM
    $VMMatch = Get-VM $VMNAme
    }
    elseif($clusterCheck -ne $null)
    {
        #The cluster service is present, lets see if it is running
        $clusterServiceStatus = Get-Service ClusSvc | Select-Object -ExpandProperty Status
        if($clusterServiceStatus -eq "Running")
        {
            $nodes = Get-ClusterNode -ErrorAction SilentlyContinue
            if($nodes -ne $null)
            {
                $CAU = Get-CauRun
                if($CAU -eq "RunNotInProgress")
                {
                $CAUState = "Cluster Aware Updating is not in Progress."
                }
                elseif($CAU -ne "RunInProgress")
                {
                $CAUState = "Cluster Aware Updating is in Progress."
                }

                $VMList  = ForEach($vm in $nodes)
                {
                #Get the state of the VM
                $VMList = Get-VM -ComputerName $vm.Name
                Get-VM -ComputerName $vm.Name 
                }
                $VMMatch = $VMList | Where {$_.Name -like $VMName}

            }
            elseif($nodes -eq $null)
            {
                Write-Host "It appears this is a Hyp cluster but no nodes were found -"`
                "ensure you are running this in an administratrive PowerShell Window" -ForegroundColor Yellow
                $AlertState = "ClusterError"
                #Get the state of the VM
                $VMMatch = Get-VM $VMNAme
            }
     }
     else{
                Write-Host "This server has the cluster service but it is not running - "`
                "now engaging Standalone diagnostic" -ForegroundColor Cyan
                $AlertState = "ClusterError"
                #Get the state of the VM
                $VMMatch = Get-VM $VMNAme
          }
      } 



    #If this is not a cluster run standalone version of script

if ($AlertState -ne "ClusterError")
{
        #Get event log where it matches the event ID 21111 which shows a VM live migration failed.  We could compare this to orignal error or ticket time  
        $LMErrorEvent = Get-WinEvent -LogName "Microsoft-Windows-Hyper-V-VMMS-Admin" -MaxEvents 200 | Where-Object {$_.ID -eq "21111"}
        #For each match check which one contains the matching VM name. 
        $ErrorMatching = $LMErrorEvent | Where-Object {$_.Message -like "*$VMName*"}
        $ErrorMatching.message
        #Just select the latest event
        $LastErrorEvent = $ErrorMatching | Sort-Object {[datetime]$_."TimeCreated"} -ErrorAction SilentlyContinue | select -Last 1

        #Get event log where it matches the event ID 20415 which shows a VM live migrated ok.  We could compare this to orignal error or ticket time  
        $LMSuccessEvent = Get-WinEvent -LogName "Microsoft-Windows-Hyper-V-VMMS-Admin" -MaxEvents 200 | Where-Object {$_.ID -eq "20415"}
        #For each match check which one contains the matching VM name. 
        $SuccessMatching = $LMSuccessEvent | Where-Object {$_.Message -like "*$VMName*"}
        $SuccessMatching.message
        #Just select the latest event
        $LastGoodEvent = $SuccessMatching | Sort-Object {[datetime]$_."TimeCreated"} -ErrorAction SilentlyContinue | select -Last 1

        #Check results if no results logs may have been cleared
        if ($LastGoodEvent -eq $null -and $LastErrorEvent -eq $null)
                    {
                        $AlertState =  "NoLogs"
                        #return $AlertState
                        #Write-Output "NoLogs"
                    }
                    #If there are some good events and error events of no error events compare the dates
                    elseif (($LastGoodEvent -ne $null -and $LastErrorEvent -eq $null) -or ($LastGoodEvent -ne $null -and $LastErrorEvent -ne $null))
                    {
                        #write-host "no error ID but a recent good event"
                        $GoodDate = $LastGoodEvent.TimeCreated
                        $ErrorDate = $LastErrorEvent.TimeCreated 
                        #If error event is more recent than good event alert has not cleared 
                        $AlertState = ($GoodDate) -gt ($ErrorDate)
                        if ($AlertState -eq  $False)
                            {
                                $AlertState =  "Bad"
                                $AlertInfo = @{
                                LastGoodEvent = $GoodDate
                                #ErrorID = $ErrorID
                                LastErrorEvent = $ErrorDate
                                AlertState = $AlertState
                                }
                            }
                            #If good event is more recent than error event alert has not cleared 
                            elseif ($AlertState -eq  $True)
                            {
                                $AlertState =  "Good"
                                $AlertInfo = @{
                                LastGoodEvent = $GoodDate
                                #ErrorID = $ErrorID
                                LastErrorEvent = $ErrorDate
                                AlertState = $AlertState
                                }
                            }
                            #return $AlertInfo  
                    }
                    #If error event is present but there is no good event alert has not cleared 
                    elseif ($LastGoodEvent -eq $null -and $LastErrorEvent -ne $null)
                    {
                        #write-host "recent error ID but no recent good event"
                        $GoodDate = $LastGoodEvent.TimeCreated
                        $AlertState = ($GoodDate) -gt ($ErrorDate)
                        $AlertState =  "Bad"
                        $AlertInfo = @{
                        LastGoodEvent = $GoodDate
                        #ErrorID = $ErrorID
                        LastErrorEvent = $ErrorDate
                        AlertState = $AlertState
                        }
    }


    if ($AlertState -eq "Good" -and $CAUState -eq "Cluster Aware Updating is in Progress." -and $VMMatch.State -eq "Running")
                 {
                    Write-Output "Hello Team,"
                    Write-Output "`n`nThe alert cleared without intervention from Rackspace. The latest good event ID is more recent than the error event. Cluster Aware Updating is in progress, there is a limit to the number of live migrations that can occur which is what caused this alert. Please review the details below for more information.`n"
                    Write-Output "`nMost recent Good Event:"
                    Write-Output "-----------------------------------------------------"
                    Write-Output "EventID     : 20415"
                    #Trimming out the whitespace from the date output as there is an new line in the output otherwise
                    $LGE =  $GoodDate.LastGoodEvent | Out-String
                    $LGEFinal = $LGE.Trim()
                    Write-Output "Event Time  : $GoodDate"
                    Write-Output "-----------------------------------------------------"
                    Write-Output "`nMost recent Error Event:"  
                    Write-Output "-----------------------------------------------------"
                    Write-Output "EventID     : 21111"
                    #Trimming out the whitespace from the date output as there is an new line in the output otherwise
                    $LEE = $ErrorDate.LastErrorEvent.TimeCreated | Out-String
                    $LEEFInal = $LEE.Trim()
                    Write-Output "Event Time  : $ErrorDate"
                    Write-Output "-----------------------------------------------------"
                    Write-Output $VMMatch
                    Write-Output "`nAs this alert has cleared we will mark this ticket as confirm solved. If you have any questions please let us know."
                    Write-Output "`n`nKind Regards,"
                    Write-Output "`nMicrosoft Virtualization Engineer"
                    Write-Output "Rackspace Toll Free: (800) 961-4454"
                 }
                 elseif($AlertState -eq "Good" -and $CAUState -eq "Cluster Aware Updating is not in Progress." -and $VMMatch.State -eq "Running")
                 {
                    Write-Output "Hello Team,"
                    Write-Output "`n`nThe alert cleared without intervention from Rackspace. The latest good event ID is more recent than the error event. Cluster Aware Updating was not found to be in progress, but may have been running at the time of the event. Please review the details below for more information.`n"
                    Write-Output "`nMost recent Good Event:"
                    Write-Output "-----------------------------------------------------"
                    Write-Output "EventID     : 20415"
                    #Trimming out the whitespace from the date output as there is an new line in the output otherwise
                    $LGE =  $GoodDate.LastGoodEvent | Out-String
                    $LGEFinal = $LGE.Trim()
                    Write-Output "Event Time  : $GoodDate"
                    Write-Output "-----------------------------------------------------"
                    Write-Output "`nMost recent Error Event:"  
                    Write-Output "-----------------------------------------------------"
                    Write-Output "EventID     : 21111"
                    #Trimming out the whitespace from the date output as there is an new line in the output otherwise
                    $LEE = $ErrorDate.LastErrorEvent.TimeCreated | Out-String
                    $LEEFInal = $LEE.Trim()
                    Write-Output "Event Time  : $ErrorDate"
                    Write-Output "-----------------------------------------------------"
                    Write-Output $VMMatch
                    Write-Output "`nAs this alert has cleared we will mark this ticket as confirm solved. If you have any questions please let us know."
                    Write-Output "`n`nKind Regards,"
                    Write-Output "`nMicrosoft Virtualization Engineer"
                    Write-Output "Rackspace Toll Free: (800) 961-4454"
                 }
                 elseif ($AlertState -eq "Bad")
                 {
                    #Private update and keep ticket open.  Add Information for tech to aid troubleshooting.
                    Write-Output "Hello Team,`n"
                    Write-Output "`nThe alert has not cleared.  The most recent error event is newer than the last reported good events.  Review details below and investigate further.`n"                
                    Write-Output "`nMost recent Error Event:"  
                    Write-Output "-----------------------------------------------------"
                    Write-Output "EventID     : 21111"
                    #Trimming out the whitespace from the date output as there is an new line in the output otherwise
                    $LEE = $ErrorDate.TimeCreated | Out-String
                    $LEEFInal = $LEE.Trim()
                    Write-Output "Event Time  : $ErrorDate"
                    Write-Output "-----------------------------------------------------"
                    Write-Output "`nMost recent Good Event:"
                    Write-Output "-----------------------------------------------------"
                    Write-Output "EventID     : 20415"
                    #Trimming out the whitespace from the date output as there is an new line in the output otherwise
                    $LGE =  $GoodDate.LastGoodEvent | Out-String
                    $LGEFinal = $LGE.Trim()
                    Write-Output "Event Time  : $GoodDate"
                    Write-Output "-----------------------------------------------------"
                    Write-Output $CAUState
                    Write-Output "-----------------------------------------------------"
                    Write-Output $VMMatch

                 }

                 elseif ($AlertState -eq "NoLogs")
                 {
                    #Private update and keep ticket open.  Add Information for tech to aid troubleshooting.
                    Write-Output "Hello Team,`n`n" 
                    Write-Output "The script ran but found no matching VM Live migration events.  The VMMS event logs may have been cleared since this alert was triggered."                
                    Write-Output "`nPlease Investigate further.`n"
                 }
   
                                  
        }
         elseif ($AlertState = "ClusterError" -and $VMMatch.State -eq "Running")
             {
                #Private update and keep ticket open.  Add Information for tech to aid troubleshooting.
                Write-Output "Hello Team,`n"
                Write-Output "`nThe alert has not cleared, the VM is running. This is either a standalone node or a cluster node where nodes or the cluster servcie is not running so other checks have not been carried out.  Please investigate issues:`n"                
                Write-Output $VMMatch
             } 
              elseif ($AlertState = "ClusterError" -and $VMMatch.State -eq "Off")
             {
                #Private update and keep ticket open.  Add Information for tech to aid troubleshooting.
                Write-Output "Hello Team,`n"
                Write-Output "`nThe alert has not cleared, the VM is not running. This is either a standalone node or a cluster node where nodes or the cluster servcie is not running so other checks have not been carried out.  Please investigate issues:`n"                
                Write-Output $VMMatch
             } 
    }
    Catch
    {
        #Information to be added to private comment in ticket when unknown error occurs
        $ErrMsg = "Powershell exception :: Line# $($_.InvocationInfo.ScriptLineNumber) :: $($_.Exception.Message)"
        Write-Output "Hello Team,`n`n"         
        Write-Output "The script failed to run, see error message below"
        Write-Output $ErrMsg
        Write-Output "`nPlease Investigate further."
    }


    <#

    The Virtual Machine Management service successfully completed the live migration of virtual machine  '903194-nyc201' with a blackout time of 0.6 seconds (VMID F5EF233C-B586-4380-B5EA-00C1D5499815).
PS C:\Users\rack>

Log Name:      Microsoft-Windows-Hyper-V-VMMS-Admin
Source:        Microsoft-Windows-Hyper-V-VMMS
Date:          11/21/2017 4:57:53 AM
Event ID:      20415
Task Category: None
Level:         Information
Keywords:      
User:          SYSTEM
Computer:      773330-hyp1.MPC1495823.local
Description:
The Virtual Machine Management service successfully completed the live migration of virtual machine  '773356-USTSTDB5' with a blackout time of 0.5 seconds (VMID E0D09432-A320-44CC-8A12-E1300549B99D).
Event Xml:
<Event xmlns="http://schemas.microsoft.com/win/2004/08/events/event">
  <System>
    <Provider Name="Microsoft-Windows-Hyper-V-VMMS" Guid="{6066F867-7CA1-4418-85FD-36E3F9C0600C}" />
    <EventID>20415</EventID>
    <Version>0</Version>
    <Level>4</Level>
    <Task>0</Task>
    <Opcode>0</Opcode>
    <Keywords>0x8000000000000000</Keywords>
    <TimeCreated SystemTime="2017-11-21T10:57:53.874847300Z" />
    <EventRecordID>52262</EventRecordID>
    <Correlation />
    <Execution ProcessID="4900" ThreadID="11504" />
    <Channel>Microsoft-Windows-Hyper-V-VMMS-Admin</Channel>
    <Computer>773330-hyp1.MPC1495823.local</Computer>
    <Security UserID="S-1-5-18" />
  </System>
  <UserData>
    <VmlEventLog xmlns:auto-ns2="http://schemas.microsoft.com/win/2004/08/events" xmlns="http://www.microsoft.com/Windows/Virtualization/Events">
      <Parameter0>773356-USTSTDB5</Parameter0>
      <Parameter1>E0D09432-A320-44CC-8A12-E1300549B99D</Parameter1>
      <Parameter2>0.5</Parameter2>
    </VmlEventLog>
  </UserData>
</Event>



RunInProgress


RunId                   : ca981cd7-2715-4351-b378-830c8c7def2d
RunStartTime            : 12/1/2017 3:00:01 AM
CurrentOrchestrator     : 809986-HYP1
NodeStatusNotifications : {
                            Node      : 809988-hyp2
                            Status    : Restarting
                            Timestamp : 12/1/2017 3:50:28 AM
                          }
NodeResults             : {
                            Node                     : 809989-hyp3
                            Status                   : Succeeded
                            ErrorRecordData          :
                            NumberOfSucceededUpdates : 2
                            NumberOfFailedUpdates    : 0
                            InstallResults           : Microsoft.ClusterAwareUpdating.UpdateInstallResult[]
                          ,
                            Node                     : 809986-hyp1
                            Status                   : Succeeded
                            ErrorRecordData          :
                            NumberOfSucceededUpdates : 2
                            NumberOfFailedUpdates    : 0
                            InstallResults           : Microsoft.ClusterAwareUpdating.UpdateInstallResult[]
                          }



                          Example ticket 

                          https://core.rackspace.com/py/ticket/view.pt?ref_no=171121-01154 

                          #>