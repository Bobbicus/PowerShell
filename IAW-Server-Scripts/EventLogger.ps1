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
    "Error" {$RSEventID = 102}
    "Info" {$RSEventID = 101}
    }

        New-EventLog -LogName Application –Source “RS Powershell Script” 
        Write-EventLog –LogName Application –Source “RS Powershell Script” –EntryType Information –EventID $RSEventID –Message $EventMessage 
    }
    else
    {
     switch ($Type)
    {
    "Error" {$RSEventID = 102}
    "Info" {$RSEventID = 101}
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





