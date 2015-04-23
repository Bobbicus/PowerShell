Import-Module WebAdministration

$Websites = Get-ChildItem IIS:\Sites

$CollectionBindings = @()
foreach ($Site in $Websites) {

    $Binding = $Site.bindings

    [string]$BindingInfo = $Binding.Collection

    [string[]]$Bindings = $BindingInfo.Split(" ")

    $bindings.count

 
    $i = 0
    $header = ""
    
    Do{

 
        Write-Output ("Site    :- " + $Site.name + " <" + $Site.id +">")

        Write-Output ("Protocol:- " + $Bindings[($i)])

        [string[]]$Bindings2 = $Bindings[($i+1)].Split(":")

        Write-Output ("IP      :- " + $Bindings2[0])
        Write-Output ("Port    :- " + $Bindings2[1])
        Write-Output ("Header  :- " + $Bindings2[2])
        $item = New-Object System.Object
        $item | Add-member -MemberType NoteProperty -Name "Site" -Value $Site.name
        $item | Add-member -MemberType NoteProperty -Name "Protocol" -Value $Bindings[($i)]
        $item | Add-member -MemberType NoteProperty -Name "IP" -Value $Bindings2[0]
        $item | Add-member -MemberType NoteProperty -Name "Port" -Value $Bindings2[1]
        $item | Add-member -MemberType NoteProperty -Name "Header" -Value $Bindings2[2]
        $CollectionBindings +=$item
   
        $i=$i+2
    
    } while ($i -lt ($bindings.count))

}

$SiteFind = Read-host "What URL do you need to match to a site"

$CollectionBindings | Select-Object Site, Header, IP, Port | Where {($_.Header -EQ $SiteFind) -or ($_.IP -EQ $SiteFind)}

