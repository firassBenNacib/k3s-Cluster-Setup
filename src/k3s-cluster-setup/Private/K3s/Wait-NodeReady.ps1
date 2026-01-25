function Wait-NodeReady {
    param([string]$MultipassCmd, [string]$PrimaryServer, [string]$NodeName, [int]$TimeoutSeconds, [int]$RemoteCmdTimeoutSeconds)
    Show-CancelHint
    Write-Host "Waiting for node '$NodeName' to become Ready..." -ForegroundColor Yellow
    $start = Get-Date
    $printed = 0
    while (((Get-Date) - $start).TotalSeconds -lt $TimeoutSeconds) {
        Stop-IfCancelled
        try {
            $cmd = ("sudo k3s kubectl wait --for=condition=Ready node/{0} --timeout=2s >/dev/null 2>&1" -f $NodeName)
            Invoke-MpTimeoutBash -MultipassCmd $MultipassCmd -InstanceName $PrimaryServer -BashCmd $cmd -TimeoutSeconds $RemoteCmdTimeoutSeconds | Out-Null
            Write-Host "$NodeName is Ready." -ForegroundColor Green
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
    Write-Warning "Timeout waiting for $NodeName to be Ready."
    return $false
}
