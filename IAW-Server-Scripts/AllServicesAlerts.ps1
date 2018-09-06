#Script Author: Fahad Javaid <fahad.javaid@rackspace.co.uk>
#Contribution/Mentor: Mark Wichall

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

Function Uptime {

$computer = $env:computername
$lastboot = (Get-WmiObject -Class Win32_OperatingSystem).LastBootUpTime
$lastboottime = [System.Management.ManagementDateTimeconverter]::ToDateTime($lastboot)
$boot = (get-date) - [System.Management.ManagementDateTimeconverter]::ToDateTime($lastboot)

""
Write-Host -fore Green  "Checking for Server Uptime Details: "
""
write-host "Servername" $computer;write-host "Current Date & Time = " (get-date);Write-Host "Last Boot Date & Time = " $lastboottime
Write-Host "Server has been up for: " $boot.days "days" $boot.hours "hours" $boot.minutes  "minutes`n";

}

function All-service ($events) {

$Userrestart = $events | where-object {$_.eventid -eq 1074} | select-object Timewritten, UserName -first 5 | ft -autosize

$unexpectedshutdown = $events | where-object {$_.eventid -eq "6008" -or $_.eventid -eq "41" } |select-object message, Timewritten -first 3 | ft -autosize

$bluescreen = Get-EventLog -LogName application -Newest 100 -Source 'Windows Error*' |
select timewritten, message | where message -match 'bluescreen' |  ft -auto -wrap

if (!$Userrestart) 
{write-host -fore Green "No matching system log events found for user initiated restart...`n"}
else {Write-host -Fore Green "Last 5 User restarts`n"; $userrestart}

if(!$unexpectedshutdown)
{Write-Host -fore Green "No matching system log events found for unexpected shutdown...`n"}
else {Write-Host -fore Red "Last three unexpected shutdowns`n"; $unexpectedshutdown}

if(!$bluescreen)
{Write-host -fore Green "No matching logs found for BSOD....`n"}
else {Write-Host -fore Red "BSOD details`n"; $bluescreen}
}

Function Using-Culture (
    [System.Globalization.CultureInfo]$culture = (throw "USAGE: Using-Culture -Culture culture -Script {scriptblock}"),
    [ScriptBlock]$script= (throw "USAGE: Using-Culture -Culture culture -Script {scriptblock}"))
{
    $OldCulture = [System.Threading.Thread]::CurrentThread.CurrentCulture
    trap
    {
        [System.Threading.Thread]::CurrentThread.CurrentCulture = $OldCulture
    }
    [System.Threading.Thread]::CurrentThread.CurrentCulture = $culture
    Invoke-Command $script
    [System.Threading.Thread]::CurrentThread.CurrentCulture = $OldCulture
}

#Author: Rodney Baulch <rodney.baulch@rackspace.co.uk>
Function Using-Culture (
    [System.Globalization.CultureInfo]$culture = (throw "USAGE: Using-Culture -Culture culture -Script {scriptblock}"),
    [ScriptBlock]$script= (throw "USAGE: Using-Culture -Culture culture -Script {scriptblock}"))
{
    $OldCulture = [System.Threading.Thread]::CurrentThread.CurrentCulture
    trap
    {
        [System.Threading.Thread]::CurrentThread.CurrentCulture = $OldCulture
    }
    [System.Threading.Thread]::CurrentThread.CurrentCulture = $culture
    Invoke-Command $script
    [System.Threading.Thread]::CurrentThread.CurrentCulture = $OldCulture
}

#Logging use to share.

Write-Host -fore Yellow "1/2 - Checking System Logs...Please wait`n"
$events = get-eventlog -logname system |where-object {$_.eventid -eq 1074 -or $_.eventid -eq "6008" -or $_.eventid -eq "41"}

Write-Host -fore Yellow "2/2 - Checking Installed Hotfixes...Please wait`n"
$Hotfixes = Using-Culture en-US { Get-HotFix | Select-Object -last 20 | Sort-Object HotFixID -Descending | Format-Table Description,HotfixID,InstalledBy,@{Name="Installation Date"; Expression={"{0:dd/MM/yyyy}" -f $_.InstalledOn}} -AutoSize } 

#Clear screen
Clear

#Logging use to share.
Try
{
    Import-Module "$Global:RootPath\Shared_Modules\Logging_Module.psm1" -EA SilentlyContinue
    Write-MasterLogFile -functionname "AllServicesAlerts" -scriptname "AllServicesAlerts" -Notes "" -Account "" -Path "$Global:RootPath"
}
Catch
{
    #Do nothing
}

#Run Functions
Uptime
All-service ($events)

Write-Host "Last 20 hotfixes installed:`n" -ForegroundColor Green
$Hotfixes