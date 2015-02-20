################################################
# Isolated FTP script
# Created by Bob Larkin 
# Date 04/10/2013
# Email: Steve.conisbee@rackspace.co.uk
################################################

<#Creates a user and add them to a FTP Group

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
$user.put('userflags',$flag)
$user.SetInfo()


#Create FTP Group
$group = $server.Create("Group","FTPUsers")
$group.SetInfo()
$group.description = "Isolated FTP Users Group"
$group.SetInfo()
$group1 =[adsi]"WinNT://$env:computername/FTPUsers,group"
$group1.Add("WinNT://$env:computername/$username,user")
