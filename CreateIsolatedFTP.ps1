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
   
$ErrorActionPreference="Stop"

import-module webadministration

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


#Create FTP Group

$group = $server.Create("Group","FTPUsers")
$group.SetInfo()
$group.description = "Isolated FTP Users Group"
$group.SetInfo()
$group1 =[adsi]"WinNT://$env:computername/FTPUsers,group"
$group1.Add("WinNT://$env:computername/$username,user")

 
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

Write-Host "...Creating AppPool: $FTPSitetitle"
New-Item IIS:\AppPools\$appPoolName -Verbose:$false | Out-Null
Write-Host "...Creating FTP Site: $ftpSiteTitle"

# Create the folder if it doesnt exist.
if(!(Test-Path "$target"))
{
New-Item $target -itemType directory
}

#Set FTP Server settings
New-Item IIS:\Sites\$ftpSiteTitle -bindings $bindings -physicalPath "c:\inetpub\ftproot" -Verbose:$false | Out-Null
Set-ItemProperty IIS:\Sites\$ftpSiteTitle -Name applicationPool -Value $appPoolName
Set-ItemProperty IIS:\Sites\$ftpSiteTitle -Name ftpServer.security.authentication.basicAuthentication.enabled -Value $true
Set-ItemProperty IIS:\Sites\$ftpSiteTitle -Name ftpServer.security.ssl.controlChannelPolicy -Value 0
Set-ItemProperty IIS:\Sites\$ftpSiteTitle -Name ftpServer.security.ssl.dataChannelPolicy -Value 0
Set-ItemProperty IIS:\Sites\$ftpSiteTitle -Name ftpServer.userisolation.mode -Value 3
#Set Virtual directory listing option this is case sensitive
Set-ItemProperty IIS:\Sites\$ftpSiteTitle -Name ftpServer.directoryBrowse.showFlags -Value 32

#Set-ItemProperty IIS:\Sites\$ftpSiteTitle -Name ftpServer.directoryBrowse.showFlags:DisplayVirtualDirectories 
Set-ItemProperty IIS:\AppPools\$appPoolName managedRuntimeVersion v4.0

#Set NTFS security on FTP target Folder
$acl = (Get-Item $actualpath).GetAccessControl("Access")
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule($ftpusername,"Modify","ContainerInherit, ObjectInherit","None","Allow")
$acl.AddAccessRule($rule)
Set-Acl $actualpath $acl

<#Configure Firewall Ports
$firewallSupport = Get-WebConfiguration system.ftpServer/firewallSupport
$firewallSupport.lowDataChannelPort = 50001
$firewallSupport.highDataChannelPort = 50050
$firewallSupport | Set-WebConfiguration system.ftpServer/firewallSupport
#>


#Create Virtual Directory Structure
New-Item "IIS:\sites\$ftpSiteTitle\LocalUser" -physicalPath $target -type VirtualDirectory
New-Item "IIS:\sites\$ftpSiteTitle\Localuser\$ftpusername" -physicalPath $target -type VirtualDirectory
New-Item "IIS:\sites\$ftpSiteTitle\Localuser\$ftpusername\$leaf" -physicalPath $actualpath -type VirtualDirectory

#Set the permissions...
Clear-WebConfiguration -Filter /System.FtpServer/Security/Authorization -PSPath IIS: -Location "$ftpSiteTitle"
#Add FTPUsers Group permission to FTP site
Add-WebConfiguration -Filter /System.FtpServer/Security/Authorization -Value (@{AccessType="Allow"; Roles="FTPUsers"; Permissions="Read"}) -PSPath IIS: -Location "$ftpSiteTitle"
#Add read write permissions to users Virtual folder
Add-WebConfiguration -Filter /System.FtpServer/Security/Authorization -Value (@{AccessType="Allow"; Users="$ftpuserName"; Permissions="Read,Write"}) -PSPath IIS: -Location "$ftpSiteTitle/LocalUser/$ftpusername/"

#Results
write-host "$ftpsitetitle FTP Site created successfully"
write-host " "
write-host "User $ftpusername created successfully with a password of $password"
write-host " "
write-host "FTP Path = $actualpath"
