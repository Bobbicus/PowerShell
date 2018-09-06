#v0.1 - Initial build
$version = "0.1"
$scriptname = "WSUS_Settings_Audit"

Try
{

Function Get-CurrentRootPath
{
<#
.Synopsis
   Get the current root path the script was executed from
.DESCRIPTION
    Starts from current folder and works down until it finds powershell_root.txt.
    Script will then set $Global:RootPath as the root directory for importing and logging
    Will work in dev folders as well as K:, X: and local temp directorys
.EXAMPLE
   Get-CurrentRootPath
.OUTPUTS
    None
#>
    #Get current path
    $Path = Split-Path $script:MyInvocation.MyCommand.Path
     
    If ($Path -eq $env:TMP)
    {
        #If our execution path is equal to temp path, we must be running on customer box downloading from media servers
        $Global:RootPath = $Path
    }
    ELSE
    {
        #We could be or K: or X:, so lets find the rootpath using the txt file
        $FolderArr = $Path.Split("\")
        $FolderCount = ($FolderArr.Count)
        do
        {
            #loop backwards through the folders until we find powershell_root.txt
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
        #If variable set, save to root folder, else cancel
        IF ($RootPath)
        {
            $Global:RootPath = $RootPath
            write-debug $Global:RootPath
        }
        ELSE
        {
            Write-Host "`nError - powershell_root.txt not found in folder.`n`n" -ForegroundColor Red
            Break;
        }
    }
}

Get-CurrentRootPath

Function Import-CustomModule {
<#
.Synopsis
   Import a customer module into your script
.DESCRIPTION
    Takes a custom module module and loads it, making sure it is loaded
    Will also do built in modules and load it, making sure it is correctly loaded
.EXAMPLE
   Import-CustomModule "$Global:RootPath\Shared_Modules\Logging_Module.psm1" -Name "Logging_Module"
.EXAMPLE
   Import-CustomModule -Name "ActiveDirectory" -builtin
.OUTPUTS
    None
#>
   Param (
   [Parameter()][string]$path,
   [Parameter()][string]$name,
   [Parameter()][switch]$builtin
   )
 
   #If builtin, just do the name
   If($builtin -eq $true)
   {
        Import-Module $name -DisableNameChecking -Force
    }
    ELSE
    {
         
        IF(Test-Path $path)
        {
            Import-Module $path -DisableNameChecking -Force
        }
        Else
        {
            #fail if we cannot find the module path
            write-host "unable to find module: $path. Script quit" -ForegroundColor Red
            break
        }
    }
     
    #get all loaded modules
    $LoadedModules = Get-Module
    #look for imported module in loaded module
    ForEach ($modulename in $LoadedModules)
    {
       IF ($modulename.name -like $name)
        {
            $loaded = $true
        }
    }
 
    #if we dont find it, write error to screen
    If($loaded -ne $true)
    {
        write-host "Unable to load $name module. Script quitting" -ForegroundColor Red
        break
    }
}
 
Import-CustomModule "$Global:RootPath\Shared_Modules\Logging_Module.psm1" -Name "Logging_Module"
#New-LogFile -ScriptName "$Scriptname"

Import-CustomModule "$Global:RootPath\BBCode\BBCode.psm1" -Name "BBCode"


Function Audit-PatchingSettings {
    # Retrieve the registry key with the main information in it
    $RegKey = Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"

    # Create a new object to save the audit information into, and add the computer name as a property (for Run-RemotePS use for account runs)
    $PatchingConfig = New-Object System.Object
    $PatchingConfig | Add-Member -Type NoteProperty -Name ServerName -Value $ENV:ComputerName

    # Is the server configured to use WSUS?
    $PatchingConfig | Add-Member -Type NoteProperty -Name UseWSUS -Value ([bool]$RegKey.UseWUServer)

    # What server is it set to use?
    $PatchingConfig | Add-Member -Type NoteProperty -Name WSUSServer -Value (Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate").WUServer

    # Is AutoUpdate turned on?
    $PatchingConfig | Add-Member -Type NoteProperty -Name AutoUpdate -Value (![bool]$RegKey.NoAutoUpdate)

    # What Patching Option is set?
    Switch ($RegKey.AUOptions) {
        "1" { $Type = "Disabled" }   
        "2" { $Type = "Notify Only" }
        "3" { $Type = "Download Only" }
        "4" { $Type = "Auto Install" }
    }
    $PatchingConfig | Add-Member -Type NoteProperty -Name PatchingType -Value $Type

    # What is the Install Day?
    Switch ($RegKey.ScheduledInstallDay) {
        "1" { $Day = "Sunday" }   
        "2" { $Day = "Monday" }
        "3" { $Day = "Tuesday" }
        "4" { $Day = "Wednesday" }
        "5" { $Day = "Thursday" }
        "6" { $Day = "Friday" }
        "7" { $Day = "Saturday" }
    }
    $PatchingConfig | Add-Member -Type NoteProperty -Name PatchingDay -Value $Day

    # What is the Install Time? (converts an Int to 24 hour time, eg 2 becomes 0200)
    Try {
        $TimeValue = New-TimeSpan -Hours $RegKey.ScheduledInstallTime
    }
    Catch { 
        # Do Nothing, there was an error being generated if the value didn't exist
    }
    $PatchingConfig | Add-Member -Type NoteProperty -Name PatchingTime -Value ('{0:00}{1:00}' -f $TimeValue.Hours,$TimeValue.Minutes)

    # Will the server reboot, regardless of whether people are logged on?
    $PatchingConfig | Add-Member -Type NoteProperty -Name AutoRebootWithLoggedOnUsers -Value (![bool]$RegKey.NoAutoRebootWithLoggedOnUsers)

    #Output the Audit
    $PatchingConfig
}

# Call the function (the function can be added to other projects and called at the appropriate time in the sequence)
Audit-PatchingSettings
$patchsettings = Audit-PatchingSettings

# You can also exclude certain properties from your output (useful if you don't need the ComputerName if it's part of a larger script)
# Audit-PatchingSettings | Select-Object UseWSUS,WSUSServer,AutoUpdate,PatchingType,PatchingDay,PatchingTime,AutoRebootWithLoggedOnUsers

$a = ConvertTo-BBCode $patchsettings -clip
write-host "The table has been saved to your clipboard as bbcode" -ForegroundColor Green
 

New-AppStatsFile -scriptname $Scriptname -version $version -Device $ENV:Computername -Account $account -functionname $function
}
Catch
{
    cls
    write-host "Unhandled exception in script" -ForegroundColor Red
}