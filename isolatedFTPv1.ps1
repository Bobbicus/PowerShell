################################################
# Isolated FTP script
# Contribution: Steve Conisbee/Bob Larkin
# Edited by Bob Larkin - 18/02/2015
################################################

<#
    .Synopsis
     This Powershell script will setup Isolated FTP.
    .Description
     The script will configure Isolated FTP on a server that has not had it configured before.
    .Example
     ".\isolatedFTP.ps1"
    .Notes
     IIS and FTP role must be installed
     YOU MUST allow script execution before this will work. ("set-executionpolicy unrestricted unrestricted").
     You must run this script from a Powershell window (do not right click, run in Powershell). Otherwise you may miss errors.
     You will be prompted to answer a few questions in order to get Isolated FTP configured.
     Creates a new user based on the name supplied. This will decide the name of the HomeFolder for the user.
     Password must be complex enough to meet the server password policy.
     Puts the newly created Isolated FTP site into it's own AppPool.
     Assumes ALL IP's for the bindings.
     When prompted for target folder, this is the folder the user will have access to. For example "c:\inetpub\wwwroot\website1"
 
 
 Bob added features

 Create an FTP Group
 Add user to the group
 Set group read permissions on top level FTP site

 #>
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

#Some older code includes this local var.
$Drive = $Global:RootPath

#v1.1 Added extra variables
#v1.0 release

Function New-LogFile{
   Param (
   [Parameter()][string]$ScriptName,
   [Parameter()][switch]$Pssession,
   [Parameter()]$Path

   )
    
    If ($Path.Count -gt 0)
    {
        CD $Path
    }

    #Check log file exists, if it doesnt, create it
    If($Global:LogCreated)
    {
        $DateTime = get-date -uFormat "%d/%m/%Y %H:%M:%S"
        #update prexisting log file
        Update-LogFile "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx" -NoConsole
        Update-LogFile "Log file already exists. Module reimported at  $DateTime" -NoConsole
        Update-LogFile "Running as user: $env:username"  -NoConsole
        Update-LogFile "Running on: $ENV:ComputerName"  -NoConsole
    }
    ELSE
    { 
        IF (-NOT (Test-Path "$Global:RootPath\LOGS\$ScriptName"))
        {
            mkdir "$Global:RootPath\LOGS\$ScriptName"  | Out-Null
             IF (-NOT (Test-Path "$Global:RootPath\LOGS\$ScriptName"))
             {write-host "FAILED TO CREATE LOGS FOLDER" -ForegroundColor RED ; BREAK}
        }

        #Create log file
        $strDateTime = get-date -uFormat "%d_%m_%Y_%H_%M_%S"

        If($Global:Dev)
        {
            $logfilepath = "$Global:RootPath\Logs\$ScriptName\DEV_$ScriptName`_$env:username`_$strDateTime.log"
        }
        ELSE
        {
            $logfilepath = "$Global:RootPath\Logs\$ScriptName\$ScriptName`_$env:username`_$strDateTime.log"
        }

        New-Item $logfilepath -Type File | Out-Null


        #update new log file
        Add-content $logfilepath -value  "#################################################"
        Add-content $logfilepath -value  "#             $ScriptName log file             #"   
        Add-content $logfilepath -value  "#################################################"  
        Add-content $logfilepath -value  "-------------------------------" 
        Add-content $logfilepath -value  "$strDateTime` : New log file created"
        Add-content $logfilepath -value  "$strDateTime` : Running as user: $env:username"
        Add-content $logfilepath -value  "$strDateTime` : Running on: $ENV:ComputerName"
    }
    $Global:LogPath = $logfilepath
    $Global:LogCreated = $True
}

Function Update-LogFile{
   Param (
   [Parameter()][string]$Message,
   [Parameter()][Switch]$NoConsole,
   [Parameter()][Switch]$NoLogFile,
   [Parameter()][string]$logfilepath = $Global:LogPath,
   [Parameter()][ValidateSet(“Error”, “Warn”, “Info”,"Success")][string] $Type = “Info”
   )

	If(-NOT (Test-Path $logfilepath))
    {
         write-host "FAILED to write to log $logfilepath"  -ForegroundColor red

        If(-NOT (Test-Path $Global:LogPath ))
        {
            #write-host "2 -NOT (Test-Path logfilepath / logfilepath = $logfilepath / Global:LogPath = $Global:LogPath"
            #write-host "FAILED2 to write to log $Global:LogPath"  -ForegroundColor red
            #write-host $Message  -ForegroundColor yellow
            #break
        }
    }
    ELSE
    {
  
   $strDateTime = get-date -uFormat "%d-%m-%Y %H:%M:%S"
    #The type of message, it will control the text colour
    switch ($Type)
    {
    "Error" {$ConsoleTextColour = 'Red'}
    "Warn" {$ConsoleTextColour = 'Yellow'}
    "Info" {$ConsoleTextColour = 'Gray'}
    "Success" {$ConsoleTextColour = 'Green'}
    }
  
    $Colour = "-ForegroundColor $ConsoleTextColour"
  
    #If outputting to the console it will do both the event log and write-host
    If($NoLogFile){
        write-host "$strDateTime : $Message" -ForegroundColor $ConsoleTextColour
        return
    }
             
    if($NoConsole)
    {
        Add-content $logfilepath -value "$strDateTime : $Message"
    }ELSE{
        Add-content $logfilepath -value "$strDateTime : $Message"
        write-host "$strDateTime : $Message" -ForegroundColor $ConsoleTextColour
    } 
    
    #Remove blank lines from log file
    (gc $logfilepath) | ? {$_.trim() -ne "" } | set-content $logfilepath


    }


    <#
    .SYNOPSIS
    Writes message to log file and screen
    .DESCRIPTION
    Pass a message to log file
    You can control if you want to write to the log and screen and the colour of the message on the screen
    .PARAMETER Message
    The content of your log entry. It is required and should be first
    .PARAMETER NoConsole
    Switch, do not write to screen
    .PARAMETER Type
    Select text colour Error = red, Warn = yellow, Info = grey (Default)
    .EXAMPLE
    Default behaviour, this message will write to the log and screen in grey and add the date.
    Write-Log "This is a standard message"
    .EXAMPLE
    Using the type parameter will change text colour
    Update-LogFile "this text will be red!" -Type Error
    .EXAMPLE
    This will not appear on screen
    Update-LogFile "This is a variable = $var" -NoConsole
    .NOTES
    Author : Martin Howlett - martin.howlett@rackspace.co.uk
    Requires : PowerShell V1
    .LINK
    None
    #>
}

Function Write-MasterLogFile
{

    Param (
    [Parameter()]$scriptname,
    [Parameter()]$functionname,
    [Parameter()]$appid,
    [Parameter()]$bizunit,
    [Parameter()]$device,
    [Parameter()]$functionid,
    [Parameter()]$ip,
    [Parameter()]$notes,
    [Parameter()]$os,
    [Parameter()]$source = $Global:Source,
    [Parameter()]$status,
    [Parameter()]$version,
    [Parameter()]$path,
    [Parameter()]$account,
    [Parameter()]$nolog = $Global:NoLog  #Disables Logging
    )

    #Added to stopping logging to audit trail.
    If ($nolog)
    {
        Write-Host "Logging - Disabled."
        Break 
    }

    $date = get-date -uFormat "%d/%m/%Y"
    $time = get-date -uFormat "%H:%M:%S"
    $username = [Environment]::UserName
    $functionid = $functionname 
    $appid = $scriptname 

    If ($Source.Length -eq 0)
    {
        $Source = "Not defined"
    }

    $Path = $Global:RootPath

<#
    #Use the global root path unless the user has specified a path
    If ($Path.Length -eq 0)
    {
        $Path = $Global:RootPath
    }
    ELSE
    {
        $Path = $Path.Split(":")[0] + ":"
    }
#>    
    #Write to the master log file
    $VarObject = New-Object PSObject -Property @{appid = $appid ; bizunit = $bizunit ; date = $date; device = $device ; functionid = $functionid ; ip = $ip ; notes = $notes ; os = $os ; source = $source ; status = $status ; time = $time ; username = $username ; version = $version ; UseCurrentDate = $true} 
    $VarObject | select appid,bizunit,date,device,functionid,ip,notes,os,source,status,time,username,version | export-csv "$path\Logs\One_Log_To_Rule_Them_All.csv" -noType  -Append -ErrorAction Stop
    Add-content $Path\Logs\One_Log_To_Rule_Them_All.log -value  "`r$appid,$bizunit,$date,$device,$functionid,$ip,$notes,$os,$source,$status,$time,$username,$version"

    #new xml code
    If ($account -ne "1103359")
    {
       
        $strDateTime = get-date -uFormat "%d_%m_%Y_%H_%M_%S"
        $LogPath = "$Global:RootPath\Logs\AppStats\ToLog"

        IF (-NOT (Test-Path "$LogPath"))
        {
            mkdir "$LogPath"  | Out-Null
        }

        $logfilepath = "$LogPath\LOG_$ScriptName`_$env:username`_$strDateTime.xml"
        $VarObject | Export-Clixml $logfilepath
    }
       
    #Try and write to the API
    #$return = Update-AppStatAPI @VarObject

}

Function Update-AppStatAPI
{

Param (
[Parameter()]$appid,
[Parameter()]$bizunit,
[Parameter()]$device,
[Parameter()]$functionid,
[Parameter()]$ip,
[Parameter()]$notes,
[Parameter()]$os,
[Parameter()]$source,
[Parameter()]$status,
[Parameter()]$version,
[Parameter()]$datey,
[Parameter()]$datem,
[Parameter()]$dated,
[Parameter()]$dateh,
[Parameter()]$datemin,
[Parameter()]$dates,
[Parameter()]$username,
[Parameter()][switch]$UseCurrentDate
)
    $psVersion = $PSVersionTable.PSVersion.Major
    #DEV $URL = "http://10.21.229.29/appstats/event/"
    $URL = "http://10.21.230.53/appstats/event/"

    #Use the global root path
    $Path  = $Global:RootPath

    If ($Username.legth -eq 0)
    {
         $username = [Environment]::UserName
    }

    If ($psVersion -ge 3)
    {   
                          
        If ($UseCurrentDate)
        {
            $date = get-date  
            $datey = $date.Year
            $datem = $date.Month
            $dated = $date.Day
            $dateh = $date.Hour
            $datemin = $date.Minute
            $dates = $date.Second
        }
         
         #appid,bizunit,date,device,functionid,ip,notes,os,source,status,time,username,version 
        
        $Functiondetails = New-Object -TypeName psobject -Property @{
            "appid" = $appid;
            "bizunit" = "$bizunit";
            "datey" = "$datey";
            "datem" = "$datem";
            "dated" = "$dated";
            "device" = "$device";
            "functionid" = "$functionid";
            "ip" = "$IP";
            "OS" = "$OS";            
            "source" = "$source";
            "status" = "$status";                      
            "dateh" = "$dateh";
            "datemin" = "$datemin";
            "dates" = "$dates"
            "username" = "$username";
            "version" = "$version";
        } 

        #Convert our object to JSON
        $JSON = $Functiondetails | ConvertTo-Json 
                
        Try
        {
            $return = Invoke-RestMethod -Uri "$URL" -Body "$JSON" -ContentType "application\json" -Method "Post"     
                
            If ($return -eq "OK")  
            {  
                Add-content $Path\Logs\AppStats\API_Success.log -value  "'r$($appid.value),$($appid.value),$($bizunit.value),$($appid.value),$($date.value),$($device.value),$($functionid.value),$($ip.value),$($notes.value),$($os.value),$($source.value),$($status.value),$($time.value),$($username.value),$($version.value)"
            }
            ELSE
            {
                #API not OK
                $fail = "API not OK"
                Add-content $Path\Logs\AppStats\API_Fail.log -value  "`r$($appid.value),$($appid.value),$($bizunit.value),$($appid.value),$($date.value),$($device.value),$($functionid.value),$($ip.value),$($notes.value),$($os.value),$($source.value),$($status.value),$($time.value),$($username.value),$($version.value)"

            }
        }
        CATCH
        {
            #API errored out
            $fail = "API catch"
            Add-content $Path\Logs\AppStats\API_Fail.log -value  "`r$appid,$bizunit,$date,$device,$functionid,$ip,$notes,$os,$source,$status,$time,$username,$version,$fail"
        }
    }
    ELSE
    {
        #no posh 3 so failed to write to API
        $fail = "No PoSh3"
        Add-content $Path\Logs\AppStats\API_Fail.log -value  "`r$appid,$bizunit,$date,$device,$functionid,$ip,$notes,$os,$source,$status,$time,$username,$version,$fail"
    }
    
    Return $return
}

<#
Function Get-CurrentRootPath
{
   $Path = Split-Path $script:MyInvocation.MyCommand.Path
   write-host $Path -ForegroundColor Yellow

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
    write-host "$Global:RootPath" -ForegroundColor Magenta
}
Get-CurrentRootPath
If ($Drive.Length -eq 0)
{
   $Drive = $Global:RootPath
}
ELSE
{
    If ($Drive -like "*:*")
    {
        $Drive = $Drive.Split(":")[0] + ":"
    }
}
#>

IF($Global:LogCreated -ne $true ){New-LogFile -ScriptName "IsolatedFTP"}
  
$ErrorActionPreference="Stop"

#Get hostname value from the registry 
#$Hostname=(Get-ItemProperty hklm:\Software\Rackspace\  -Name Hostname).Hostname
$ComputerName = $ENV:ComputerName
Update-LogFile -Message "Local computer name  = $ComputerName" -Type info -NoConsole
import-module webadministration

Write-Host "Starting Isoalted FTP Configuration" -ForegroundColor Green
Write-Host " "
#Create User
$username = Read-Host 'Please enter a username'
$server=[adsi]"WinNT://$env:computername"
$user=$server.Create("User","$username")
$password = Read-Host 'Please enter a Password'
$user.SetPassword($password)

$user.SetInfo()
 
#Add extra info
$user.Put('Description','FTP Account')
#$flag=$user.UserFlags.Value -bor 0x800000
#$user.put('userflags',$flag)
$user.SetInfo()
Update-LogFile -Message "Created local User $username" -Type Success

#Create FTP Group

$group = $server.Create("Group","FTPUsers")
$group.SetInfo()
$group.description = "Isolated FTP Users Group"
$group.SetInfo()
$group1 =[adsi]"WinNT://$env:computername/FTPUsers,group"
$group1.Add("WinNT://$env:computername/$username,user")
Update-LogFile -Message "Created Local Group FTPUsers" -Type Success
 
#Add extra info

$flag=$user.UserFlags.Value -bor 0x800000
#Bob updated Target to remove username
$target = "C:\inetpub\FTPHomeFolder"
$ftpSiteTitle = "Isolated FTP"
$appPoolName = $ftpSiteTitle
$ftpUserName  = $username
$actualpath = read-host "Enter Path to target folder"
$leaf=split-path "$actualpath" -leaf

Write-Host ".SITE: $ftpSiteTitle"


# ftp site creation
$bindings = '@{protocol="' + "FTP" + '";bindingInformation="'+ "*:21:" +'"}'
Update-LogFile -Message "Created AppPool: $FTPSitetitle" -Type Success
Write-Host "...Creating AppPool: $FTPSitetitle"
New-Item IIS:\AppPools\$appPoolName -Verbose:$false | Out-Null
Write-Host "...Creating FTP Site: $ftpSiteTitle"

# Create the folder if it doesnt exist.
if(!(Test-Path "$target"))
{
New-Item $target -itemType directory
Update-LogFile -Message "Created Home Folder $target" -Type Success
}

#Set FTP Server settings
New-Item IIS:\Sites\$ftpSiteTitle -bindings $bindings -physicalPath "c:\inetpub\ftproot" -Verbose:$false | Out-Null
Update-LogFile -Message "Created New IIS Site $ftpSiteTitle" -Type Success
Set-ItemProperty IIS:\Sites\$ftpSiteTitle -Name applicationPool -Value $appPoolName
Update-LogFile -Message "Created New IIS Site $ftpSiteTitle" -Type Success -NoConsole
Set-ItemProperty IIS:\Sites\$ftpSiteTitle -Name ftpServer.security.authentication.basicAuthentication.enabled -Value $true
Update-LogFile -Message "Configured site $ftpSiteTitle to use basic authentication" -Type Success -NoConsole
Set-ItemProperty IIS:\Sites\$ftpSiteTitle -Name ftpServer.security.ssl.controlChannelPolicy -Value 0
Set-ItemProperty IIS:\Sites\$ftpSiteTitle -Name ftpServer.security.ssl.dataChannelPolicy -Value 0
Set-ItemProperty IIS:\Sites\$ftpSiteTitle -Name ftpServer.userisolation.mode -Value 3
Update-LogFile -Message "Set User mode isolation - User name Directory disable global viryual directory" -Type Success -NoConsole
#Set Virtual directory listing option this is case sensitive
Set-ItemProperty IIS:\Sites\$ftpSiteTitle -Name ftpServer.directoryBrowse.showFlags -Value 32
Update-LogFile -Message "Set display Virtual Directory setting" -Type Success -NoConsole

#Set-ItemProperty IIS:\Sites\$ftpSiteTitle -Name ftpServer.directoryBrowse.showFlags:DisplayVirtualDirectories 
Set-ItemProperty IIS:\AppPools\$appPoolName managedRuntimeVersion v4.0

#Set NTFS security on FTP target Folder
$acl = (Get-Item $actualpath).GetAccessControl("Access")
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule($ftpusername,"Modify","ContainerInherit, ObjectInherit","None","Allow")
$acl.AddAccessRule($rule)
Set-Acl $actualpath $acl
Update-LogFile -Message "Configure modify permissions for $ftpusername on folder $actualpath" -Type Success -NoConsole


<#Configure Firewall Ports
$firewallSupport = Get-WebConfiguration system.ftpServer/firewallSupport
$firewallSupport.lowDataChannelPort = 50001
$firewallSupport.highDataChannelPort = 50050
$firewallSupport | Set-WebConfiguration system.ftpServer/firewallSupport
#>


#Create Virtual Directory Structure
New-Item "IIS:\sites\$ftpSiteTitle\LocalUser" -physicalPath $target -type VirtualDirectory
Update-LogFile -Message "Created New virtual Folder LocalUser $ftpSiteTitle" -Type Success -NoConsole
New-Item "IIS:\sites\$ftpSiteTitle\Localuser\$ftpusername" -physicalPath $target -type VirtualDirectory
Update-LogFile -Message "Created New IIS Site LocalUser\$ftpSiteTitle" -Type Success -NoConsole
New-Item "IIS:\sites\$ftpSiteTitle\Localuser\$ftpusername\$leaf" -physicalPath $actualpath -type VirtualDirectory

#Set the permissions...
Clear-WebConfiguration -Filter /System.FtpServer/Security/Authorization -PSPath IIS: -Location "$ftpSiteTitle"

#Add FTPUsers Group permission to FTP site
Add-WebConfiguration -Filter /System.FtpServer/Security/Authorization -Value (@{AccessType="Allow"; Roles="FTPUsers"; Permissions="Read"}) -PSPath IIS: -Location "$ftpSiteTitle"
#Add read write permissions to users Virtual folder
Add-WebConfiguration -Filter /System.FtpServer/Security/Authorization -Value (@{AccessType="Allow"; Users="$ftpuserName"; Permissions="Read,Write"}) -PSPath IIS: -Location "$ftpSiteTitle/LocalUser/$ftpusername/"
Update-LogFile -Message "Configured Authorization setting on Virtual Folders" -Type Success -NoConsole

#Results
Update-LogFile -Message "$ftpsitetitle Site created successfully" -Type Success 
Update-LogFile -Message "User $ftpusername created successfully" -Type Success 
Update-LogFile -Message "FTP Path = $actualpath" -Type Success
Write-Host " "
Update-LogFile -Message "FTP Home site $ftpsitetitle FTP Site created successfully" -Type info -NoLogFile
Update-LogFile -Message "Username: $ftpusername" -Type info -NoLogFile
Update-LogFile -Message "Password: $password" -Type info -NoLogFile
Update-LogFile -Message "FTP Path: $actualpath" -Type info -NoLogFile


