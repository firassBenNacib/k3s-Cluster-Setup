function Set-K3sKubeconfigNames {
    param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][string]$ClusterName)

    if (-not (Test-Path -LiteralPath $Path)) {
        return
    }
    $raw = Get-Content -LiteralPath $Path -Raw -ErrorAction Stop
    if ([string]::IsNullOrWhiteSpace($raw)) {
        return
    }

    $raw = Convert-KubeconfigYamlText -Text $raw

    if ($raw -match '(?m)^current-context:\s*') {
        $raw = [regex]::Replace($raw, '(?m)^current-context:\s*.*$', "current-context: $ClusterName")
    }
    else {
        $raw = $raw.TrimEnd() + [Environment]::NewLine + "current-context: $ClusterName" + [Environment]::NewLine
    }

    $raw = [regex]::Replace($raw, '(?m)^(\s*-?\s*name:\s*)default\s*$', { param($m) $m.Groups[1].Value + $ClusterName })
    $raw = [regex]::Replace($raw, '(?m)^(\s*cluster:\s*)default\s*$', { param($m) $m.Groups[1].Value + $ClusterName })
    $raw = [regex]::Replace($raw, '(?m)^(\s*user:\s*)default\s*$', { param($m) $m.Groups[1].Value + $ClusterName })

    Write-Utf8File -Path $Path -Content $raw

    if (Get-Command kubectl -ErrorAction SilentlyContinue) {
        [void](Clear-KubeconfigLockFiles -CandidateKubeconfigPaths @($Path) -WaitSeconds 5)
        $result = Invoke-NativeCommandSafe -FilePath "kubectl" -CommandArgs @("--kubeconfig", $Path, "config", "view", "--raw")
        if ($result.ExitCode -ne 0) {
            throw "Generated kubeconfig at '$Path' is not valid for kubectl (parse failed)."
        }
    }
}
