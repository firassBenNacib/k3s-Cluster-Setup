function New-K3sServerExecArgs {
    param(
        [bool]$IsInitServer,
        [bool]$UseClusterInit,
        [bool]$DisableFlannel,
        [bool]$DisableTraefik,
        [bool]$DisableServiceLB,
        [bool]$DisableMetricsServer,
        [string]$JoinServerIP
    )
    $k3sArgs = @()
    if (-not [string]::IsNullOrWhiteSpace($JoinServerIP)) {
        $k3sArgs += "server"
        $k3sArgs += ("--server https://{0}:6443" -f $JoinServerIP)
    }
    else {
        $k3sArgs += "server"
        if ($UseClusterInit -and $IsInitServer) {
            $k3sArgs += "--cluster-init"
        }
    }

    if ($DisableFlannel) {
        $k3sArgs += "--flannel-backend=none"
        $k3sArgs += "--disable-network-policy"
    }
    if ($DisableTraefik) {
        $k3sArgs += "--disable=traefik"
    }
    if ($DisableServiceLB) {
        $k3sArgs += "--disable=servicelb"
    }
    if ($DisableMetricsServer) {
        $k3sArgs += "--disable=metrics-server"
    }

    return ($k3sArgs -join " ")
}
