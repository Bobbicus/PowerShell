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
Checks if IIS and FTP roles are intalled, will install these if they are not present.
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
    Write-Host "IIS Role installed" -Type Success
    add-WindowsFeature Web-Mgmt-Tools
    Write-Host "IIS Management Tools installed" -Type Success
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
    Write-Host "FTP Role Installed" -Type Success
}

function New-FTPSite
{

  #Changed import method to work with PS v2.0
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
        
        Write-Host "FTP Site exists, exiting the script" 
        break
    }
else
    {
        
        #$ErrorActionPreference="Stop"

        #Get hostname value from the registry
        #$Hostname=(Get-ItemProperty hklm:\Software\Rackspace\ -Name Hostname).Hostname
        $ComputerName = $ENV:ComputerName
        Write-Host "Local computer name = $ComputerName" -ForegroundColor Yellow

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
        Write-Host "Created local User $username" -ForegroundColor Yellow

        #Create FTP Group

        $group = $server.Create("Group","FTPUsers")
        $group.SetInfo()
        $group.description = "Isolated FTP Users Group"
        $group.SetInfo()
        $group1 =[adsi]"WinNT://$env:computername/FTPUsers,group"
        $group1.Add("WinNT://$env:computername/$username,user")
        Write-Host "Created Local Group FTPUsers" -ForegroundColor Yellow
        #Add extra info

        $flag=$user.UserFlags.Value -bor 0x800000
        #Bob updated Target to remove username
        $target = "C:\inetpub\FTPHomeFolder"
        $ftpSiteTitle = "Isolated FTP"
        $appPoolName = $ftpSiteTitle
        $ftpUserName = $username
        $actualpath = read-host "Enter Path to target folder"
        $leaf=split-path "$actualpath" -leaf

        Write-Host ".SITE: $ftpSiteTitle" -ForegroundColor Yellow


        # ftp site creation
        $bindings = '@{protocol="' + "FTP" + '";bindingInformation="'+ "*:21:" +'"}'
        Write-Host "Created AppPool: $FTPSitetitle" -ForegroundColor Yellow
        Write-Host "...Creating AppPool: $FTPSitetitle" -ForegroundColor Yellow
        New-Item IIS:\AppPools\$appPoolName -Verbose:$false | Out-Null
        Write-Host "...Creating FTP Site: $ftpSiteTitle" -ForegroundColor Yellow

        # Create the folder if it doesnt exist.
        if(!(Test-Path "$target"))
        {
            New-Item $target -itemType directory
            Write-Host "Created Home Folder $target" -Type Success
        }

        #Set FTP Server settings
        New-Item IIS:\Sites\$ftpSiteTitle -bindings $bindings -physicalPath "c:\inetpub\ftproot" -Verbose:$false | Out-Null
        Write-Host "Created New IIS Site $ftpSiteTitle" -ForegroundColor Yellow
        Set-ItemProperty IIS:\Sites\$ftpSiteTitle -Name applicationPool -Value $appPoolName
        Write-Host "Created New IIS Site $ftpSiteTitle" -ForegroundColor Yellow 
        Set-ItemProperty IIS:\Sites\$ftpSiteTitle -Name ftpServer.security.authentication.basicAuthentication.enabled -Value $true
        Write-Host "Configured site $ftpSiteTitle to use basic authentication" -ForegroundColor Yellow
        Set-ItemProperty IIS:\Sites\$ftpSiteTitle -Name ftpServer.security.ssl.controlChannelPolicy -Value 0
        Set-ItemProperty IIS:\Sites\$ftpSiteTitle -Name ftpServer.security.ssl.dataChannelPolicy -Value 0
        Set-ItemProperty IIS:\Sites\$ftpSiteTitle -Name ftpServer.userisolation.mode -Value 3
        Write-Host "Set User mode isolation - User name Directory disable global viryual directory" -ForegroundColor Yellow
        #Set Virtual directory listing option this is case sensitive
        Set-ItemProperty IIS:\Sites\$ftpSiteTitle -Name ftpServer.directoryBrowse.showFlags -Value 32
        Write-Host "Set display Virtual Directory setting" -ForegroundColor Yellow

        #Set-ItemProperty IIS:\Sites\$ftpSiteTitle -Name ftpServer.directoryBrowse.showFlags:DisplayVirtualDirectories
        Set-ItemProperty IIS:\AppPools\$appPoolName managedRuntimeVersion v4.0

        #Set NTFS security on FTP target Folder
        $acl = (Get-Item $actualpath).GetAccessControl("Access")
        $rule = New-Object System.Security.AccessControl.FileSystemAccessRule($ftpusername,"Modify","ContainerInherit, ObjectInherit","None","Allow")
        $acl.AddAccessRule($rule)
        Set-Acl $actualpath $acl
        Write-Host "Configure modify permissions for $ftpusername on folder $actualpath" -ForegroundColor Yellow


        <#Configure Firewall Ports
        $firewallSupport = Get-WebConfiguration system.ftpServer/firewallSupport
        $firewallSupport.lowDataChannelPort = 50001
        $firewallSupport.highDataChannelPort = 50050
        $firewallSupport | Set-WebConfiguration system.ftpServer/firewallSupport
        #>


        #Create Virtual Directory Structure
        New-Item "IIS:\sites\$ftpSiteTitle\LocalUser" -physicalPath $target -type VirtualDirectory
        Write-Host "Created New virtual Folder LocalUser $ftpSiteTitle" -ForegroundColor Yellow
        New-Item "IIS:\sites\$ftpSiteTitle\Localuser\$ftpusername" -physicalPath $target -type VirtualDirectory
        Write-Host "Created New IIS Site LocalUser\$ftpSiteTitle"  -ForegroundColor Yellow
        New-Item "IIS:\sites\$ftpSiteTitle\Localuser\$ftpusername\$leaf" -physicalPath $actualpath -type VirtualDirectory

        #Set the permissions...
        Clear-WebConfiguration -Filter /System.FtpServer/Security/Authorization -PSPath IIS: -Location "$ftpSiteTitle"

        #Add FTPUsers Group permission to FTP site
        Add-WebConfiguration -Filter /System.FtpServer/Security/Authorization -Value (@{AccessType="Allow"; Roles="FTPUsers"; Permissions="Read"}) -PSPath IIS: -Location "$ftpSiteTitle"
        #Add read write permissions to users Virtual folder
        Add-WebConfiguration -Filter /System.FtpServer/Security/Authorization -Value (@{AccessType="Allow"; Users="$ftpuserName"; Permissions="Read,Write"}) -PSPath IIS: -Location "$ftpSiteTitle/LocalUser/$ftpusername/"
        Write-Host "Configured Authorization setting on Virtual Folders" -ForegroundColor Yellow

        #Results
        Write-Host "$ftpsitetitle Site created successfully" -ForegroundColor Green
        Write-Host "User $ftpusername created successfully" -ForegroundColor Green
        Write-Host "FTP Path = $actualpath `n" -ForegroundColor Green
        Write-Host "FTP Home site $ftpsitetitle FTP Site created successfully"  -ForegroundColor Green
        Write-Host "Username: $ftpusername" -ForegroundColor Green
        Write-Host "Password: $password" -ForegroundColor Green
        Write-Host "FTP Path: $actualpath" -ForegroundColor Green
    }

}
New-FTPSite


