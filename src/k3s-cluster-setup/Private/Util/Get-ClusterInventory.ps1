function Get-ClusterInventory {
    param([string]$MultipassCmd, [switch]$IncludeDeleted)

    $instances = @()
    $obj = Get-MultipassListJson -MultipassCmd $MultipassCmd
    if ($obj -and $obj.list) {
        $instances = @($obj.list)
    }
    if (-not $IncludeDeleted) {
        $instances = @($instances | Where-Object { $_.state -ne 'Deleted' })
    }

    $clusters = @{}
    foreach ($vm in $instances) {
        $n = $vm.name

        if ($n -match '^k3s-(srv|agt)(\d+)-(.+)$') {
            $c = $matches[3]
            if (-not $clusters.ContainsKey($c)) {
                $clusters[$c] = [ordered]@{ Servers = @(); Agents = @(); Ambiguous = @() }
            }
            if ($matches[1] -eq 'srv') {
                $clusters[$c].Servers += $n
            }
            else {
                $clusters[$c].Agents += $n
            }
            continue
        }

        if ($n -match '^k3s-server-(.+)$') {
            $c = $matches[1]
            if (-not $clusters.ContainsKey($c)) {
                $clusters[$c] = [ordered]@{ Servers = @(); Agents = @(); Ambiguous = @() }
            }
            $clusters[$c].Servers += $n
            continue
        }

        if ($n -match '^k3s-agent-(.+)-(\d+)$') {
            $c = $matches[1]
            if (-not $clusters.ContainsKey($c)) {
                $clusters[$c] = [ordered]@{ Servers = @(); Agents = @(); Ambiguous = @() }
            }
            $clusters[$c].Agents += $n
            continue
        }
    }

    $all = Get-UniqueList -Items $clusters.Keys
    return [pscustomobject]@{ Instances = $instances; Clusters = $clusters; Names = $all }
}
