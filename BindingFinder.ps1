################################################
# IIS Binding Finder
# Contribution: Bob Larkin
# Edited - 08/05/2015
################################################

<#
    .Synopsis
     This Powershell script will search for specific header or IP.
    .Description
     The script will search for specific headeror IP binding in IIS.  You can choose to list all bindings.  The output is formatted as BBcode ready for use in ticket updates.
     
    .Example
     
    .Notes

    Server version  | Tested  |
    --------------------------
    Server 2003 x32 |    ?    |
    Server 2003 x64 |    ?    |
    Server 2008 x32 |    N    |
    Server 2008 x64 |    N    |
    Server 2008 R2  |    Y    |
    Server 2012     |    Y    |
    Server 2012 R2  |    Y    |

requires -version 2.0

    
 #>

function FindWebBinding
{
    Param(
    [Parameter()]$FindSite = (Read-host "Enter Host header or IP (Wildcards * are allowed) enter A for all")
    )
    

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

  
    $Websites = Get-ChildItem IIS:\Sites

    #Create a collection to store the Bindings
    $CollectionBindings = @()
        foreach ($Site in $Websites) {

            $Binding = $Site.bindings

            [string]$BindingInfo = $Binding.Collection

            [string[]]$Bindings = $BindingInfo.Split(" ")

    
 
            $i = 0
    #Split the results of the bindings using : as the separator.  Store the values in the collection
    #This means we can reference the IP, Port and Header as separate objects, usually they are stored as one string. 
         Do{

 
            [string[]]$Bindings2 = $Bindings[($i+1)].Split(":")

        
                $item = New-Object PSObject @{}
                $item | Add-member -MemberType NoteProperty -Name "Site" -Value $Site.name
                $item | Add-member -MemberType NoteProperty -Name "Protocol" -Value $Bindings[($i)]
                $item | Add-member -MemberType NoteProperty -Name "IP" -Value $Bindings2[0]
                $item | Add-member -MemberType NoteProperty -Name "Port" -Value $Bindings2[1]
                $item | Add-member -MemberType NoteProperty -Name "Header" -Value $Bindings2[2]
                $CollectionBindings +=$item
   
                $i=$i+2
        
    
            } while ($i -lt ($bindings.count))

    }
        #If the input is 'A' this will list all binidngs otherwise it will just output the binidng that matches the users input.
        if ($FindSite -eq 'A')
           {
                $data = $CollectionBindings | Select-Object Site, Header, IP, Port 
           }
        else
           {
                $data = $CollectionBindings | Select-Object Site, Header, IP, Port | Where {($_.Header -EQ $FindSite) -or ($_.IP -EQ $FindSite)}
           }

                #Output results in BBCode for use in tickets
                $BBTable = @(); $data | ConvertTo-HTML `
                | foreach {$_ -replace "&#160;",""} `
                | foreach {$_ -replace "<table>","[table]"} `
                | foreach {$_ -replace "<th>","[td][b]"} `
                | foreach {$_ -replace "</th>","[/b][/td]"} `
                | foreach {$_ -replace "<tr>","[tr]"} `
                | foreach {$_ -replace "<td>","[td]"} `
                | foreach {$_ -replace "</td>","[/td]"} `
                | foreach {$_ -replace "</tr>","[/tr]"} `
                | foreach {$_ -replace "</table>","[/table]"} `
                | foreach {if ($_ -like "[[]t*")  {$BBTable += $_} elseif ($_ -like "[[]/t*") {$BBTable += $_} };
                Write-Host -ForegroundColor Green "Content to be converted to BBcode:"; $Data;
                Try {$BBTable | clip} Catch {Write-Host -ForegroundColor Red "Error using Clip.exe, check path."; Break};
                Write-Host -ForegroundColor Green "BBcode Table sent to clipboard, paste into core ticket. Preview ticket before submitting.";

} 
FindWebBinding

