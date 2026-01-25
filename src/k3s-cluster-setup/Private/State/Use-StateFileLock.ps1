function Use-StateFileLock {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][scriptblock]$ScriptBlock,
        [int]$TimeoutSeconds = 20,
        [int]$PollMs = 200
    )

    $lockPath = "$StatePath.lock"

    if (-not (Get-Variable -Scope Script -Name __StateLockRefCount -ErrorAction SilentlyContinue)) {
        $script:__StateLockRefCount = 0
        $script:__StateLockHandle = $null
    }

    if ($script:__StateLockRefCount -gt 0 -and $script:__StateLockHandle) {
        $script:__StateLockRefCount++
        try {
            return & $ScriptBlock
        }
        finally {
            $script:__StateLockRefCount--
        }
    }

    $dir = Split-Path -Parent $lockPath
    if (-not [string]::IsNullOrWhiteSpace($dir) -and -not (Test-Path -LiteralPath $dir)) {
        try {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }
        catch {
            Write-NonFatalError $_
        }
    }

    $start = Get-Date
    $handle = $null
    while (-not $handle) {
        try {

            $handle = [System.IO.File]::Open(
                $lockPath,
                [System.IO.FileMode]::OpenOrCreate,
                [System.IO.FileAccess]::ReadWrite,
                [System.IO.FileShare]::None
            )
        }
        catch {
            if (((Get-Date) - $start).TotalSeconds -ge $TimeoutSeconds) {
                throw "Could not acquire state lock '$lockPath' within ${TimeoutSeconds}s. Another process may be running. If this persists unexpectedly, close other shells/IDEs using this tool and retry."
            }
            Start-Sleep -Milliseconds $PollMs
        }
    }

    $script:__StateLockHandle = $handle
    $script:__StateLockRefCount = 1

    try {
        return & $ScriptBlock
    }
    finally {
        $script:__StateLockRefCount = 0
        try { $script:__StateLockHandle.Dispose() } catch { }
        $script:__StateLockHandle = $null

        for ($i = 0; $i -lt 5; $i++) {
            try {
                Remove-Item -LiteralPath $lockPath -Force -ErrorAction SilentlyContinue
                break
            }
            catch {
                Start-Sleep -Milliseconds 200
            }
        }
    }
}
