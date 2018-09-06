<#
    .SYNOPSIS
    Replaces the DNS search suffix list on the public NIC
    
    .DESCRIPTION
    Full description: Overrides the DNS search suffix list on the public NIC with the suffixes specified by the user, to RS defaults or clears the list.
    WHAM - supported: Yes
    WHAM - keywords: DNS,network,public,nic,card,domain name server,suffix,search
    WHAM - Prerequisites: No
    WHAM - Makes changes: Yes
    WHAM - Column Header: DNS suffix list set
                 
    .EXAMPLE 
    Full command: Set-DNSSuffixList
    Output: true/false
    
    .PARAMETER Force
    Description: Supresses all user confirmation from script
    Example use: Set-DNSSuffixList -Force
    Type: String
    Default: None

    .PARAMETER DNSSuffixes
    Description: The DNS suffixes to set on the public adapter
    WHAM Prompt: Enter 1 to remove all DNS Suffixes, 2 to set Rackspace defaults or enter the DNS suffixes (Example: a.local,b.local)
    Example use: Set-DNSServers -DNSServers "a.local,b.local"
    Type: String
    Default: None
    
    .NOTES
    Author: Thomas Bottrill
    Modified: Bob Larkin / Mark Wichall
    Minimum OS: 2008 R2
    Minimum PoSh: 3.0
    Date: 08/12/2015
    Version: 3.0
    Approved by: Martin Howlett 14/01/2016

#>
Function Set-DNSSuffixList
{

Param(
    [Parameter(Mandatory=$true)]$DNSSuffixes,
    [switch]$Force
)
Try
    {
        # Requires -version 2.0

        # Skip the user validation if the force parameter is used
        if (-not $Force) 
        {
            # Confirm that the user wants to make changes
            if((Read-Host "Warning, you are about to set the DNS servers, are you sure you wish to continue? (Y/N)") -notlike "y*")
            {
                exit
            } 
        }
        
        if ($DNSSuffixes -eq "2")
        {
            #Check the registry to find datacenter location of the server
            $RSRegKeys = Get-ItemProperty -path HKLM:\HKEY_LOCAL_MACHINE\SOFTWARE\Rackspace -ErrorAction SilentlyContinue
            $DClocation = $RSRegKeys.Datacenter
            #Set the Rackspace deffault DNS suffix order according to the server Location
            if ($DClocation -like "ORD*")
            {
                $DNSSuffixesList = @("ord.intensive.int","intensive.int","dfw.intensive.int","iad.intensive.int","lon.intensive.int","hkg.intensive.int","syd.intensive.int") 
            }
            elseif ($DClocation -like "DFW*")
            {
                $DNSSuffixesList = @("dfw.intensive.int","intensive.int","iad.intensive.int","ord.intensive.int","lon.intensive.int","hkg.intensive.int","syd.intensive.int")
            }
            elseif ($DClocation -like "IAD*")
            {
                $DNSSuffixesList = @("iad.intensive.int","intensive.int","dfw.intensive.int","ord.intensive.int","lon.intensive.int","hkg.intensive.int","syd.intensive.int")
            }
            elseif ($DClocation -like "LON*")
            {
                $DNSSuffixesList = @("lon.intensive.int","intensive.int","dfw.intensive.int","iad.intensive.int","ord.intensive.int","hkg.intensive.int","syd.intensive.int")
            }
            elseif ($DClocation -like "HKG*")
            {
                $DNSSuffixesList = @("hkg.intensive.int","intensive.int","dfw.intensive.int","iad.intensive.int","ord.intensive.int","lon.intensive.int","syd.intensive.int") 
            }
            elseif ($DClocation -like "SYD*")
            {
                $DNSSuffixesList = @("syd.intensive.int","intensive.int","dfw.intensive.int","iad.intensive.int","ord.intensive.int","lon.intensive.int","hkg.intensive.int")
            }
            else
            {
                return "Failed to set DNS search suffix list - registry keys not found"
                break
            }
        }
        else
        {
            #If use input a custom DNS list "custom"
            $DNSSuffixes = $DNSSuffixes -replace "\s",""
            #Convert the string of DNSservers to an array
            $DNSSuffixes = $DNSSuffixes.Split(",")
        }

        #Checks if dnssuffixes have been added to var, if not don't make changes or you will blank out any existing ones.
        if ((($DNSSuffixesList | Measure-Object).count -gt 0) -or ($DNSSuffixes -eq "1"))
        {
            if ($DNSSuffixes -eq "1")
            {
                $DNSSuffixesList = $null
            }
            
            #Set the DNS search suffix list
            $Return = Invoke-WmiMethod -Class Win32_NetworkAdapterConfiguration -Name SetDNSSuffixSearchOrder -ArgumentList $DNSSuffixesList,$null -ErrorAction SilentlyContinue

            #return if success or not based on the WMI return value
            if (($Return.ReturnValue -eq 0) -and ($DNSSuffixes -eq "1"))
            {
                return "Successfully removed the DNS suffix list"
            }
            elseif ($Return.ReturnValue -eq 0)
            {
                return "Successfully set DNS search suffix list"
            }
            else
            {
                return "Failed to set DNS search suffix list"
            }
        }
        else
        {
            return "Failed to set DNS search suffix list - No DNSSuffixes Specified."
        }
    }
    Catch
    {
        Return $_
    }
}
