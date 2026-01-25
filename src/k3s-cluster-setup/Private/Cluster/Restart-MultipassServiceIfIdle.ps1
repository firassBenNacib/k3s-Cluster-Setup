function Restart-MultipassServiceIfIdle {
    param([Parameter(Mandatory=$true)][string]$MultipassCmd)

    $isWin = ($env:OS -eq 'Windows_NT') -or ($PSVersionTable.PSEdition -eq 'Desktop')
    if (-not $isWin) {
        return $false
    }

    try {
        $listObj = Get-MultipassListJson -MultipassCmd $MultipassCmd
        $running = @()
        if ($listObj -and $listObj.list) {
            $running = @($listObj.list | Where-Object { $_.state -eq 'Running' })
        }
        if ($running.Count -gt 0) {
            Write-Verbose "Multipass service restart skipped; running instances detected."
            return $false
        }
    }
    catch {
        Write-NonFatalError $_
    }

    $svc = $null
    try {
        $svc = Get-Service -Name "multipass" -ErrorAction SilentlyContinue
        if (-not $svc) {
            $svc = Get-Service -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -match 'multipass' -or $_.DisplayName -match 'Multipass' } |
                Select-Object -First 1
        }
    }
    catch {
        Write-NonFatalError $_
        return $false
    }

    if (-not $svc) {
        Write-Verbose "Multipass service not found; cannot restart."
        return $false
    }

    try {
        if ($svc.Status -eq 'Running') {
            Restart-Service -Name $svc.Name -Force -ErrorAction Stop
        }
        else {
            Start-Service -Name $svc.Name -ErrorAction Stop
        }
        Start-Sleep -Seconds 3
        return $true
    }
    catch {
        $msg = $_.Exception.Message
        if ($msg -match '(?i)access is denied|requires elevation|administrator') {
            Write-Warning "Restarting the Multipass service failed due to permissions. Run PowerShell as Administrator and execute: Restart-Service $($svc.Name)"
        }
        else {
            Write-Warning ("Restarting the Multipass service failed: {0}" -f $msg)
        }
        return $false
    }
}

