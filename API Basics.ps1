 $username = "robe4172"
 
 $Response = Invoke-RestMethod -Uri "https://ws.core.rackspace.com/ctkapi/login/robe4172" -Body "{`"password`":`"42240878`"}" -ContentType "application\json" -Method "Post"

 #Validate Auth token 
 https://ws.core.rackspace.com/ctkapi/session/47411c3b281ac3a07b4ce55b3ac3a2bf

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

$COREToken = "53240b287bb68cf29de17124e44eb2d8"



#query the API this uses the contents of $JSON object
$results = Invoke-RestMethod -Uri "https://ws.core.rackspace.com/ctkapi/query" -ContentType "application\json" -Method "Post" -Headers @{"X-Auth"=$COREToken} -Body $JSON -TimeoutSec 180

$results.result

