function Get-NewServerName([string]$cluster, [int]$index) { return ("k3s-srv{0}-{1}" -f $index, $cluster) }

function Get-NewAgentName([string]$cluster, [int]$index) { return ("k3s-agt{0}-{1}" -f $index, $cluster) }

function Test-ClusterExists {
    param([string]$MultipassCmd, [string]$ClusterName)
    $obj = Get-MultipassListJson -MultipassCmd $MultipassCmd
    if (-not $obj -or -not $obj.list) {
        return $false
    }
    $rxNewSrv = '^k3s-srv\d+-' + [regex]::Escape($ClusterName) + '$'
    $rxNewAgt = '^k3s-agt\d+-' + [regex]::Escape($ClusterName) + '$'
    foreach ($vm in $obj.list) {
        $n = $vm.name
        if ($n -match $rxNewSrv -or $n -match $rxNewAgt) {
            return $true
        }
        if ($n -eq ("k3s-server-" + $ClusterName)) {
            return $true
        }
        if ($n -match ('^k3s-agent-' + [regex]::Escape($ClusterName) + '-\d+$')) {
            return $true
        }
    }
    return $false
}
