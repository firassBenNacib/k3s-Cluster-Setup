function Resolve-MergedKubeconfigForUse {
    param([string]$PathLike, [string]$ClusterName)

    if (-not [string]::IsNullOrWhiteSpace($PathLike)) {
        $pp = Expand-UserPath $PathLike
        if (Test-Path -LiteralPath $pp) {
            return (Resolve-Path -LiteralPath $pp).Path
        }
        $p2 = Resolve-LocalPath -PathLike $pp -DefaultName $pp
        if (Test-Path -LiteralPath $p2) {
            return (Resolve-Path -LiteralPath $p2).Path
        }
        throw "Merged kubeconfig not found: $PathLike"
    }

    if (-not [string]::IsNullOrWhiteSpace($ClusterName)) {
        $state = Get-State
        if ($state.clusters -and ($state.clusters -is [hashtable]) -and $state.clusters.ContainsKey($ClusterName)) {
            $e = $state.clusters[$ClusterName]
            if ($e -and (Test-HasProperty -Object $e -Name "merged") -and $e.merged) {
                $mp = Expand-UserPath $e.merged
                if ($mp -and (Test-Path -LiteralPath $mp)) {
                    return (Resolve-Path -LiteralPath $mp).Path
                }
            }
            if ($e -and (Test-HasProperty -Object $e -Name "kubeconfig") -and $e.kubeconfig) {
                $kp = Expand-UserPath $e.kubeconfig
                if ($kp -and (Test-Path -LiteralPath $kp)) {
                    return (Resolve-Path -LiteralPath $kp).Path
                }
            }
        }
    }

    $here = Get-Location
    $direct = Join-Path $here "kubeconfig-merged.yaml"
    if (Test-Path -LiteralPath $direct) {
        return $direct
    }

    $userCfg = Get-UserKubeconfigFilePath
    if ($userCfg -and (Test-Path -LiteralPath $userCfg)) {
        return (Resolve-Path -LiteralPath $userCfg).Path
    }

    throw "No kubeconfig found (provide -MergedKubeconfigName, run create with -MergeKubeconfig, or pass a cluster name)."
}
