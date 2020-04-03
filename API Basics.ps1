 $username = "robe4172"
 
 $Response = Invoke-RestMethod -Uri "https://api.com/ctkapi/login/user1" -Body "{`"password`":`"42240878`"}" -ContentType "application\json" -Method "Post"

 #Validate Auth token 
 https://api.com/ctkapi/session/312654654sdf654asd65454asdf

$ComputerAttributes = @(
        "account.name",
        "number",
        "name",
        "primary_ip",
        "primary_nat_ip",
        "is_windows",
        "os_name",
        "nickname",
        "status.active",
        "status.name",
        "os_type",
        "platform_name",
        "platform_type",
        "is_online",
        "datacenter.name",
        "ports.display_name",
        "vcc",
        "dracnet_ip",
        "account",
        "attached_devices",
        "is_windows",
        "offline_date",
        "attached_firewalls",
        "date_online",
        "account_domain_info.domain_name",
        "account_domain_info.add_userid_to_domain"
    )

 $obj = @(
            @{
                "class" = "Computer.Computer";
                "load_arg" = "393689"
                "attributes" = $ComputerAttributes 
            }
    )

    #Convert it 
    $JSON = $obj | ConvertTo-Json -Depth 10


return $JSON

$COREToken = "312654654sdf654asd65454asdf"



#query the API this uses the contents of $JSON object
$results = Invoke-RestMethod -Uri "https://api.com/ctkapi/query" -ContentType "application\json" -Method "Post" -Headers @{"X-Auth"=$COREToken} -Body $JSON -TimeoutSec 180

$results.result

