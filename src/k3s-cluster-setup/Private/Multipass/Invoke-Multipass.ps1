function Invoke-Multipass {
    param(
        [Parameter(Mandatory)][string]$MultipassCmd,
        [Parameter(Mandatory)][string[]]$MpArgs,
        [switch]$AllowNonZero,
        [int]$TimeoutSeconds = 0
    )

    Stop-IfCancelled

    $out = $null
    $code = 0

    try {
        if ($TimeoutSeconds -gt 0) {
            $stdoutFile = [System.IO.Path]::GetTempFileName()
            $stderrFile = [System.IO.Path]::GetTempFileName()
            try {
                $proc = Start-Process -FilePath $MultipassCmd -ArgumentList $MpArgs -NoNewWindow -PassThru `
                    -RedirectStandardOutput $stdoutFile -RedirectStandardError $stderrFile

                if (-not $proc.WaitForExit([Math]::Max(1, $TimeoutSeconds) * 1000)) {
                    try { $proc.Kill() } catch { }
                    $code = 124
                    $outText = ""
                    try {
                        $outText = (Get-Content -LiteralPath $stdoutFile -Raw -ErrorAction SilentlyContinue) +
                            (Get-Content -LiteralPath $stderrFile -Raw -ErrorAction SilentlyContinue)
                    } catch { }
                    $out = @()
                    if (-not [string]::IsNullOrWhiteSpace($outText)) {
                        $out = $outText -split "`r?`n"
                    }
                    throw ("multipass {0} timed out after {1}s." -f ($MpArgs -join " "), $TimeoutSeconds)
                }

                $code = $proc.ExitCode
                if ($null -eq $code) {
                    $code = 0
                }
                $outText = (Get-Content -LiteralPath $stdoutFile -Raw -ErrorAction SilentlyContinue) +
                    (Get-Content -LiteralPath $stderrFile -Raw -ErrorAction SilentlyContinue)
                $out = @()
                if (-not [string]::IsNullOrWhiteSpace($outText)) {
                    $out = $outText -split "`r?`n"
                }
            }
            finally {
                try { Remove-Item -LiteralPath $stdoutFile -Force -ErrorAction SilentlyContinue } catch { }
                try { Remove-Item -LiteralPath $stderrFile -Force -ErrorAction SilentlyContinue } catch { }
            }
        }
        else {
            $out = & $MultipassCmd @MpArgs 2>&1
            $code = $LASTEXITCODE
            if ($null -eq $code) {
                $code = 0
            }
        }
    }
    catch {
        if ($_.Exception -is [System.Management.Automation.PipelineStoppedException]) {
            $script:CancelRequested = $true
            $global:K3S_CLUSTER_SETUP_CANCEL_REQUESTED = $true
            throw [System.OperationCanceledException]::new("Cancelled by user (Ctrl+C).")
        }
        throw
    }

    Stop-IfCancelled

    if (Test-IsCtrlCExitCode -Code $code) {
        $script:CancelRequested = $true
        $global:K3S_CLUSTER_SETUP_CANCEL_REQUESTED = $true
        throw [System.OperationCanceledException]::new("Cancelled by user (Ctrl+C).")
    }

    if (-not $AllowNonZero -and $code -ne 0) {
        $msg = ($out | Out-String).Trim()
        if ([string]::IsNullOrWhiteSpace($msg)) {
            $msg = "No output."
        }
        throw ("multipass {0} failed (exit {1}): {2}" -f ($MpArgs -join " "), $code, $msg)
    }

    return , $out
}
