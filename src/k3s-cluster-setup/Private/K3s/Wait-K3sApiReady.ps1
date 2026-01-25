function Wait-K3sApiReady {
    param([string]$MultipassCmd, [string]$ServerInstance, [int]$TimeoutSeconds, [int]$RemoteCmdTimeoutSeconds)
    Show-CancelHint
    Write-Host "Waiting for k3s API on $ServerInstance ..." -ForegroundColor Yellow
    $start = Get-Date
    $printed = 0
    while (((Get-Date) - $start).TotalSeconds -lt $TimeoutSeconds) {
        Stop-IfCancelled
        try {
            $cmd = "test -f /etc/rancher/k3s/k3s.yaml && sudo k3s kubectl get --raw='/readyz' >/dev/null 2>&1"
            Invoke-MpTimeoutBash -MultipassCmd $MultipassCmd -InstanceName $ServerInstance -BashCmd $cmd -TimeoutSeconds $RemoteCmdTimeoutSeconds | Out-Null
            Write-Host "$ServerInstance k3s API is reachable." -ForegroundColor Green
            return $true
        }
        catch {
            Write-NonFatalError $_
        }
        if ($printed -lt 60) {
            Write-Host "." -NoNewline -ForegroundColor DarkGray; $printed++
        }
        else {
            Write-Host ""; $printed = 0
        }
        Start-Sleep -Seconds 2
    }
    Write-Host ""
    Write-Warning "Timeout waiting for k3s API on $ServerInstance."
    return $false
}
