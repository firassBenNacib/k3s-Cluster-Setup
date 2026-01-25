function Clear-KubeconfigLockFiles {
    [CmdletBinding()]
    param(
        [string[]]$CandidateKubeconfigPaths = @(),

        [int]$MinAgeSeconds = 120,
        [int]$WaitSeconds = 5,
        [int]$PollMs = 200,
        [switch]$AllowDelete
    )

    $items = New-Object System.Collections.ArrayList

    foreach ($kc in @($CandidateKubeconfigPaths)) {
        if ([string]::IsNullOrWhiteSpace($kc)) {
            continue
        }

        $p = $kc
        if (Test-Path -LiteralPath $p) {
            try { $p = (Resolve-Path -LiteralPath $p).Path } catch { }
        }

        $dir = $null
        try {
            if (Test-Path -LiteralPath $p -PathType Container) {
                $dir = $p
            }
            else {
                $dir = Split-Path -Parent $p
            }
        }
        catch {
            $dir = Split-Path -Parent $p
        }

        if (-not [string]::IsNullOrWhiteSpace($dir)) {
            $lock = Join-Path $dir "config.lock"
            if (-not $items.Contains($lock)) { [void]$items.Add($lock) }
        }

        if (-not $items.Contains("$p.lock")) { [void]$items.Add("$p.lock") }
    }

    $allClear = $true

    foreach ($f in @($items)) {
        if (-not (Test-Path -LiteralPath $f)) {
            continue
        }

        $start = Get-Date
        while ((Test-Path -LiteralPath $f) -and (((Get-Date) - $start).TotalSeconds -lt $WaitSeconds)) {
            Start-Sleep -Milliseconds $PollMs
        }

        if (-not (Test-Path -LiteralPath $f)) {
            continue
        }

        $allClear = $false

        if (-not $AllowDelete) {
            Write-Verbose "Kubeconfig lock still present: $f"
            continue
        }

        $ageOk = $false
        try {
            $age = ((Get-Date) - (Get-Item -LiteralPath $f).LastWriteTime).TotalSeconds
            if ($age -ge $MinAgeSeconds) { $ageOk = $true }
        }
        catch {
            Write-Verbose ("Unable to stat lock file '{0}': {1}" -f $f, $_.Exception.Message)
        }

        if (-not $ageOk) {
            Write-Verbose "Kubeconfig lock not old enough to delete (MinAgeSeconds=$MinAgeSeconds): $f"
            continue
        }

        $fs = $null
        try {
            $fs = [System.IO.File]::Open($f, [System.IO.FileMode]::Open, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
        }
        catch {
            Write-Verbose ("Lock file appears to be held (exclusive open failed), not deleting: {0} ({1})" -f $f, $_.Exception.Message)
            continue
        }
        finally {
            if ($fs) {
                try { $fs.Dispose() } catch { }
            }
        }

        try {
            Remove-Item -LiteralPath $f -Force -ErrorAction Stop
            Write-Verbose "Deleted stale kubeconfig lock: $f"
        }
        catch {
            Write-Verbose ("Failed to delete kubeconfig lock '{0}': {1}" -f $f, $_.Exception.Message)
        }
    }

    return $allClear
}
