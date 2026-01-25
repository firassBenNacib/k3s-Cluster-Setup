function Wait-NodeRegistered {
    param([string]$MultipassCmd, [string]$PrimaryServer, [string]$NodeName, [int]$TimeoutSeconds, [int]$RemoteCmdTimeoutSeconds)
    Show-CancelHint
    Write-Host "Waiting for $NodeName to register..." -ForegroundColor Yellow
    $start = Get-Date
    $printed = 0
    while (((Get-Date) - $start).TotalSeconds -lt $TimeoutSeconds) {
        Stop-IfCancelled
        try {
            $cmd = ("sudo k3s kubectl get node {0} --no-headers >/dev/null 2>&1" -f $NodeName)
            Invoke-MpTimeoutBash -MultipassCmd $MultipassCmd -InstanceName $PrimaryServer -BashCmd $cmd -TimeoutSeconds $RemoteCmdTimeoutSeconds | Out-Null
            Write-Host "$NodeName registered." -ForegroundColor Green
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
    Write-Warning "Timeout waiting for $NodeName to register."
    return $false
}
