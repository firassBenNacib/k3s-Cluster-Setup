function Test-K3sReady {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$MultipassCmd,
        [Parameter(Mandatory)][string]$Primary,
        [int]$RemoteCmdTimeoutSeconds = 10
    )

    try {
        $cmd = "test -f /etc/rancher/k3s/k3s.yaml && sudo k3s kubectl get --raw='/readyz' >/dev/null 2>&1"
        Invoke-MpTimeoutBash -MultipassCmd $MultipassCmd -InstanceName $Primary -BashCmd $cmd -TimeoutSeconds $RemoteCmdTimeoutSeconds | Out-Null
        return $true
    }
    catch {
        return $false
    }
}
