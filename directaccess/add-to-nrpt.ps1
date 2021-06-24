function add-nrptRuleToDA {
    param (
        $uri, 
        $dagpos
    )
    $res=@();
    if ($uri){
        foreach ($gpo in $DAgpos){
            write-host -nonewline "Adding to $($gpo.DisplayName).. "
            $DAPol = Get-DnsClientNrptRule -GpoName $($gpo.DisplayName)
            $DADNSServer = $(($DAPol.DADnsServers | Where-Object {$_ -match "3333::"} | Sort-Object -Unique).IPAddressToString)
            if (($dapol | Where-Object {$_.namespace -match "$uri"}).count -eq 0){
                $ar = Add-DnsClientNrptRule -DAEnable -Namespace "$uri" -NameEncoding Utf8WithoutMapping -DANameServers "$DADNSServer" -GpoName "$($gpo.displayname)" -PassThru
                write-host "Done."
                $res += $ar
            }else{
                write-host "$uri already exists in nrpt"
            }
        }
    }else{
        write-host "no uri!"
    }
    return $res
}




function get-daClientGPOs {
    $dagpos_cache_path = "$($env:temp)\dagpos.b88"
    $sb_create_cache = {
        write-host  "Enumerating GPOs ... ";
        $GPOs = Get-GPO -All;
        write-host "GPOs enumerated.";
        $DAGPOs = $GPOs | Where-Object {$_.DisplayName -match "DirectAccess Client Settings"};
        write-host "Determine what are DA client GPOs ...";
        [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($($dagpos| Select-Object displayname,id | ConvertTo-Json))) | out-file "$dagpos_cache_path";
    }
    if (test-path $dagpos_cache_path){
        $eJob = Get-Job | Where-Object Name -eq "DAGPOCacheJob"
        $dagpos = [System.Text.Encoding]::Unicode.GetString([System.Convert]::FromBase64String($(Get-Content "$($dagpos_cache_path)"))) | ConvertFrom-Json
        if ($ejob){
            switch($ejob[0].State){
                "Completed" {$ejob[0] | Remove-Job -Force}
            }
        }else{
            Start-Job -ScriptBlock $sb_create_cache -Name "DAGPOCacheJob"
        }
    }else{
        & $sb_create_cache
        write-host "Enumerating GPOs takes a while, run the same command again in a few mins ..."
    }
    return $DAGPOs
}


function add-uriToDA($uri){
    $exclusions = @("AP06")
    $dagpo = $nagpo = @();
    $gpos =  get-daClientGPOs 
    $gpos | ForEach-Object {$dn = $_;
        foreach ($exc in $exclusions){
            $nagpo += $($dn | Where-Object {$dn.displayname -match "$exc"})
        }
        if ($dn.displayname -notin $nagpo.displayname){$dagpo += $dn}
    }
    if ($uri.substring(0,1) -ne "."){$uri = ".$($uri)"}
    $dagpo | ForEach-Object {add-nrptRuleToDA $uri $($_)}
    $dagpo = $null
}

if ($args[0]){
    write-host $args[0]
}
