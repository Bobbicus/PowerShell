################################################
# IIS Binding Finder
# Contribution: Bob Larkin
# Edited - 08/05/2015
################################################

<#
    .Synopsis
     This Powershell script will display search for specific header or IP.
    .Description
     The script will display all site bindings, it will allow you to search for an IP or Header 
    .Example
     
    .Notes
     
 #>

function FindWebBinding
{
    Param([
    Parameter()]$FindSite = (Read-host "Enter Host header or IP (Wildcards * are allowed) enter A for all:")
    )


Import-Module WebAdministration

$Websites = Get-ChildItem IIS:\Sites

#Create a collection to store the Bindings
$CollectionBindings = @()
foreach ($Site in $Websites) {

    $Binding = $Site.bindings

    [string]$BindingInfo = $Binding.Collection

    [string[]]$Bindings = $BindingInfo.Split(" ")

    #$bindings.count
 
    $i = 0
    #Split the results of the bindings using : as the separator.  Store the values in the collection
    #This means we can reference the IP, Port and Header as separate objects. 
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

#$CollectionBindings | Format-Table


#$CollectionBindings | Select-Object Site, Header, IP, Port | Where {($_.Header -EQ $FindSite) -or ($_.IP -EQ $FindSite)}
if ($FindSite -eq 'A')
{
$data = $CollectionBindings | Select-Object Site, Header, IP, Port 
}
else
{
$data = $CollectionBindings | Select-Object Site, Header, IP, Port | Where {($_.Header -EQ $FindSite) -or ($_.IP -EQ $FindSite)}
}
#Out put results in BBCode for use in tickets
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

