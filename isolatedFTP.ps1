################################################
# Isolated FTP script
#
# Author: Bob Larkin
# Contribution: Steve Conisbee
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
# v1-1 - Approved by Martin Howlett 24/06/2015
# v1-0 - Approved by Martin Howlett 13/05/2015
################################################

$scriptname = "IsolatedFTP"
$version = "1.1"




<#
.Synopsis
This Powershell script will setup Isolated FTP.
.Description
The script will configure Isolated FTP on a server that has not had it configured before.
.Example
".\isolatedFTP.ps1"
.Notes
YOU MUST allow script execution before this will work. ("set-executionpolicy unrestricted unrestricted").
You will be prompted to answer a few questions in order to get Isolated FTP configured.
Checks if IIS and FTP roles are intalle, will install these if they are not present.
Creates a new FTPUSer Group.
Creates a new user and adds it to the group.
Creates a new user based on the name supplied. This will decide the name of the HomeFolder for the user.
Password must be complex enough to meet the server password policy.
Puts the newly created Isolated FTP site into it's own AppPool.
Assumes ALL IP's for the bindings.
When prompted for target folder, this is the folder the user will have access to. For example "c:\inetpub\wwwroot\website1"
New Features

Now works with 2012 and 2008 R2.  Not yet tested on 2008 but should work as there is logic to work with IIS7.

#>

 #Used to find root of folder for loading other code using powershell_root.txt


Write-Host “This code will make changes to the server" -ForegroundColor Yellow
Write-Host “This script will create a new local user group, local user and a FTP site in IIS."
Write-Host "If IIS and FTP roles are not present the script will install them, do you want to continue? [Y/N]” -ForegroundColor Yellow
$YesNo = Read-host “ “
If ($YesNo –ne “y”)
{
    Write-Host “`nExiting back to menu.`n`n” -ForegroundColor Yellow
    Break
}

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

Function Import-CustomModule {

   Param (
   [Parameter()][string]$path,
   [Parameter()][string]$name,
   [Parameter()][switch]$builtin
   )

   If($builtin -eq $true)
   {
        Import-Module $name -Force
    }
    ELSE
    {
        
        IF(Test-Path $path)
        {
            Import-Module $path -DisableNameChecking -Force
        }
        Else
        {
            write-host "unable to find $path. Script quit" -ForegroundColor Red
            break
        }
    }
    
    $LoadedModules = Get-Module
    ForEach ($modulename in $LoadedModules)
    {
       IF ($modulename.name -like $name)
        {
            $loaded = $true
        }
    }

    If($loaded -ne $true)
    {
        write-host "Unable to load $name module. Script quitting" -ForegroundColor Red
        break
    }

}

#Import out custom modules
Import-CustomModule -path "$Global:RootPath\Shared_Modules\Logging_Module.psm1" -Name "Logging_Module"
If($Global:LogCreated -ne $true ){New-LogFile -ScriptName "IsolatedFTP"}

#Check if IIS role is installed. Install IIS Role if required
$GetIIS = Get-WindowsFeature -Name web-Server
$IISStatus = $GetIIS.Installed

If ($IISStatus -eq 'True')
{
    write-host "IIS role installed"
}
else
{
    add-WindowsFeature -Name Web-Server
    Update-LogFile -Message "IIS Role installed" -Type Success
    add-WindowsFeature Web-Mgmt-Tools
    Update-LogFile -Message "IIS Management Tools installed" -Type Success
}


#Check if FTP role is installed. Install FTP Role if required
$GetFTP = Get-WindowsFeature -Name web-FTP-Server
$FTPStatus = $GetFTP.Installed

If ($FTPStatus -eq 'True')
{
    write-host "FTP role installed"
}
else
{
    add-WindowsFeature -Name Web-FTP-Server
    Update-LogFile -Message "FTP Role Installed" -Type Success
}

function New-FTPSite
{

  # Changed import method to work with PS v2.0
  #Import-Module WebAdministration
  $iisVersion = Get-ItemProperty "HKLM:\software\microsoft\InetStp";
if ($iisVersion.MajorVersion -eq 8)
    {
        Import-Module WebAdministration
    }

if ($iisVersion.MajorVersion -eq 7)
{
   
    if ($iisVersion.MinorVersion -ge 5 )
    {
        Import-Module WebAdministration
    }
    else
    {
         if (-not (Get-PSSnapIn | Where {$_.Name -eq "WebAdministration";})) {
            Add-PSSnapIn WebAdministration;
        }
    }
}  

  
Import-Module WebAdministration

$Websites = Get-ChildItem IIS:\Sites

#Create a collection to store the Bindings
foreach ($Site in $Websites) {

    [string]$Binding = $Site.bindings.Collection
     $SiteProtocol = $Site.bindings.Collection | select -Property protocol
 
 If ($SiteProtocol.protocol -eq 'FTP')
  {
  $FTPPresent = $true
  }
  else
  {
  $FTPPresent = $false
  }
 
}

If ($FTPPresent)
    {
        
        Update-LogFile -Message "FTP Site exists, exiting the script" -Type info -NoLogFile
        break
    }
else
    {
        
#$ErrorActionPreference="Stop"

#Get hostname value from the registry
#$Hostname=(Get-ItemProperty hklm:\Software\Rackspace\ -Name Hostname).Hostname
$ComputerName = $ENV:ComputerName
Update-LogFile -Message "Local computer name = $ComputerName" -Type info -NoConsole


import-module webadministration

Write-Host "Starting Isolated FTP Configuration" -ForegroundColor Green
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
$ftpUserName = $username
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

    }

}
New-FTPSite

New-AppStatsFile -scriptname $scriptname -version $version -Device $ENV:Computername
