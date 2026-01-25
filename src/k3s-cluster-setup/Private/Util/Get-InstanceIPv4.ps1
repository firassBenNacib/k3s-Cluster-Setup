function Get-InstanceIPv4 {
    param([string]$MultipassCmd, [string]$InstanceName)
    $raw = $null
    try {
        $raw = Invoke-Multipass -MultipassCmd $MultipassCmd -MpArgs @("info", "--format", "json", $InstanceName)
    }
    catch {
        $raw = $null
    }

    $obj = $null
    if ($raw) {
        try {
            $obj = ($raw | Out-String | ConvertFrom-Json)
        }
        catch {
            $obj = $null
        }
    }

    $inst = $null
    if ($obj) {
        if ($obj.info -and $obj.info.$InstanceName) {
            $inst = $obj.info.$InstanceName
        }
        elseif ($obj.$InstanceName) {
            $inst = $obj.$InstanceName
        }
    }
    if ($inst -is [System.Array]) {
        $inst = $inst[0]
    }

    $ips = @()
    if ($inst -and $inst.ipv4) {
        foreach ($ip in @($inst.ipv4)) {
            $t = ($ip | Out-String).Trim()
            if ($t -match '^\d{1,3}(\.\d{1,3}){3}$') {
                $ips += $t
            }
        }
    }
    $ips = @($ips | Sort-Object -Unique)
    if ($ips.Count -eq 0) {
        try {
            $list = Get-MultipassListJson -MultipassCmd $MultipassCmd
            if ($list -and $list.list) {
                $vm = $list.list | Where-Object { $_.name -eq $InstanceName } | Select-Object -First 1
                if ($vm -and $vm.ipv4) {
                    foreach ($ip in @($vm.ipv4)) {
                        $t = ($ip | Out-String).Trim()
                        if ($t -match '^\d{1,3}(\.\d{1,3}){3}$') {
                            $ips += $t
                        }
                    }
                }
            }
        }
        catch {
        }
        $ips = @($ips | Sort-Object -Unique)
    }
    if ($ips.Count -eq 0) {
        throw "Could not determine IPv4 for instance '$InstanceName'."
    }

    $preferred = @($ips | Where-Object { $_ -notmatch '^10\.42\.' -and $_ -notmatch '^10\.43\.' -and $_ -notmatch '^169\.254\.' -and $_ -notmatch '^127\.' })
    if ($preferred.Count -gt 0) {
        return $preferred[0]
    }
    return $ips[0]
}
