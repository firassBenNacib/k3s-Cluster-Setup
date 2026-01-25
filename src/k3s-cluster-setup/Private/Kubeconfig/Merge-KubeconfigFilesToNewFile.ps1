function Merge-KubeconfigFilesToNewFile {
    param([Parameter(Mandatory)][string[]]$InputFiles, [Parameter(Mandatory)][string]$OutputFile)

    if (-not (Get-Command kubectl -ErrorAction SilentlyContinue)) {
        throw "kubectl not found in PATH."
    }

    $resolved = New-Object System.Collections.ArrayList
    foreach ($f in @($InputFiles)) {
        if ([string]::IsNullOrWhiteSpace($f)) {
            continue
        }
        if (Test-Path -LiteralPath $f) {
            $rp = (Resolve-Path -LiteralPath $f).Path
            if (-not $resolved.Contains($rp)) {
                [void]$resolved.Add($rp)
            }
        }
    }
    if (@($resolved).Count -lt 1) {
        throw "No kubeconfig files found to merge."
    }

    [void](Clear-KubeconfigLockFiles -CandidateKubeconfigPaths @($resolved + @($OutputFile)) -WaitSeconds 5)

    $old = $env:KUBECONFIG
    $sep = [System.IO.Path]::PathSeparator
    $env:KUBECONFIG = ($resolved -join $sep)
    try {
        $mergedText = $null
        $lastErr = ""
        for ($i = 0; $i -lt 6; $i++) {
            [void](Clear-KubeconfigLockFiles -CandidateKubeconfigPaths @($resolved + @($OutputFile)) -WaitSeconds 5)
            $result = Invoke-NativeCommandSafe -FilePath "kubectl" -CommandArgs @("config", "view", "--raw", "--flatten")
            $outText = ($result.Output | Out-String)
            if ($result.ExitCode -eq 0 -and -not [string]::IsNullOrWhiteSpace($outText)) {
                $mergedText = $outText
                break
            }
            $lastErr = $outText.Trim()
            if ($lastErr -match 'config\.lock') {
                Start-Sleep -Milliseconds 300; continue
            }
            $msg = if ($lastErr) {
                $lastErr
            }
            else {
                "kubectl config view --raw --flatten failed."
            }
            throw $msg
        }
        if ([string]::IsNullOrWhiteSpace($mergedText)) {
            throw "kubectl config view --raw --flatten failed due to config.lock."
        }
        $dir = Split-Path -Parent $OutputFile
        if ($dir) {
            New-SafeDirectory -Path $dir
        }
        Write-Utf8File -Path $OutputFile -Content $mergedText
    }
    finally {
        $env:KUBECONFIG = $old
    }
}
