function Get-KubeconfigJson {
    param([Parameter(Mandatory)][string]$KubeconfigPath)

    if (-not (Get-Command kubectl -ErrorAction SilentlyContinue)) {
        return $null
    }
    if (-not (Test-Path -LiteralPath $KubeconfigPath)) {
        return $null
    }

    [void](Clear-KubeconfigLockFiles -CandidateKubeconfigPaths @($KubeconfigPath) -WaitSeconds 5)
    $result = Invoke-NativeCommandSafe -FilePath "kubectl" -CommandArgs @("--kubeconfig", $KubeconfigPath, "config", "view", "-o", "json")
    if ($result.ExitCode -ne 0 -or [string]::IsNullOrWhiteSpace($result.Output)) {
        return $null
    }

    $cfg = $null
    try {
        $cfg = ($result.Output | ConvertFrom-Json)
    }
    catch {
        Write-Verbose ("Failed to parse kubeconfig JSON for '$KubeconfigPath': {0}" -f $_.Exception.Message)
        return $null
    }
    if (-not $cfg) {
        return $null
    }

    foreach ($p in @("clusters", "contexts", "users")) {
        if (-not (Test-HasProperty -Object $cfg -Name $p) -or $null -eq $cfg.$p) {
            $cfg | Add-Member -NotePropertyName $p -NotePropertyValue @() -Force
        }
        elseif ($cfg.$p -isnot [System.Array]) {
            $cfg.$p = @($cfg.$p)
        }
    }

    if (-not (Test-HasProperty -Object $cfg -Name "current-context") -or $null -eq $cfg."current-context") {
        $cfg | Add-Member -NotePropertyName "current-context" -NotePropertyValue "" -Force
    }

    return $cfg
}
