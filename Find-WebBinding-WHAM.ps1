<#
    .SYNOPSIS
    This Powershell script will search for specific header or IP
     
    .DESCRIPTION
    Full description: Search IIS Web Bindings
    WHAM - supported: Yes
    WHAM - keywords:IIS,Bindings
    WHAM - Prerequisites: No
    WHAM - Makes changes: No
    WHAM - Column Header: IIS Bindings
    
    .PARAMETER FindSite
    Description: Prompt user for Binding
    WHAM Prompt: Enter Host header or IP (Wildcards * are allowed) enter A for all
    Example use: <example command>
    Default: A
                 
    .EXAMPLE
    Full command: Find-WebBinding
    Output: 
            ServerName : 456789-WEB1
            Site       : example.com
            Header     : www.example.com
            IP         :
            Port       : 80
       
    .NOTES
    Author: Bob Larkin
    Date: <The date>
    Minimum OS: 2008 R2
    Minimum PoSh: 2.0
    Version: 1.0
    Approved by:
#>
Function Find-WebBinding
{

    Param(
    [Parameter(Mandatory=$true)]$FindSite
    
    )
        #[Parameter()]$FindSite = (Read-host "Enter Host header or IP (Wildcards * are allowed) enter A for all")

    
    Try
    {
        #Changed import method to work with PS v2.0
        #Import-Module WebAdministration
        
        $iisRegKey= Get-ItemProperty "HKLM:\software\microsoft\InetStp\Components" -ErrorAction SilentlyContinue
        $IISInstalled = $iisRegKey.W3SVC
 
    
        IF ($IISInstalled -ne 1)
        {

            $NoIISData = New-Object PSObject -Property @{     
                Site =  "IIS not installed"
                Protocol = "-"
                IP =  "-"
                Port =  "-"
                Header =  "-"
                ServerName = $ENV:ComputerName
           

            }
            $Output = $NoIISData | Select-Object ServerName, Site, Header, IP, Port
            return $Output
            break
        }
       
            $iisVersion = Get-ItemProperty "HKLM:\software\microsoft\InetStp" -ErrorAction SilentlyContinue
            if ($iisVersion.MajorVersion -eq 8)
            {
                Import-Module WebAdministration
            }
        
            #Check the versions of IIS to import the WebAdministration module in the right way
            if ($iisVersion.MajorVersion -eq 7)
            {
   
                if ($iisVersion.MinorVersion -ge 5 )
                {
                    Import-Module WebAdministration
                }
                else
                {
                    if (-not (Get-PSSnapIn | Where {$_.Name -eq "WebAdministration";})) 
                    {
                        Add-PSSnapIn WebAdministration;
                    }
                }
            }  

            #Get a list of the websites in IIS 
            $Websites = Get-ChildItem IIS:\Sites

            #Create a collection to store the Bindings
            $CollectionBindings = @()

            foreach ($Site in $Websites) 
            {
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
                    $item | Add-member -MemberType NoteProperty -Name "ServerName" -Value $ENV:ComputerName

                    $CollectionBindings +=$item
                    $i=$i+2   
                    } while ($i -lt ($bindings.count))
            }
        
            #If the input is 'A' this will list all binidngs otherwise it will just output the binidng that matches the users input.
            if ($FindSite -eq 'A')
            {
                $data = $CollectionBindings | Select-Object ServerName, Site, Header, IP, Port
 
            }
            else
            {
                $data = $CollectionBindings | Select-Object ServerName, Site, Header, IP, Port | Where {($_.Header -like "*$FindSite*") -or ($_.IP -like "*$FindSite*")}
            }
        
        Return  $data
            
        } 
        Catch
        {
        Return "Unknown Error"
        }
      
}
