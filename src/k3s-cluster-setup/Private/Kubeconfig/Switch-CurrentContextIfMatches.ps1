function Switch-CurrentContextIfMatches {
    param([Parameter(Mandatory)][string]$KubeconfigPath, [Parameter(Mandatory)][string]$BadContext)
    if (-not (Get-Command kubectl -ErrorAction SilentlyContinue)) {
        return
    }
    if (-not (Test-Path -LiteralPath $KubeconfigPath)) {
        return
    }
    $currentRaw = Invoke-KubectlConfigReadSafe -KubeconfigPath $KubeconfigPath -KubectlArgs @("config", "current-context") -Retries 2
    $current = if ($null -eq $currentRaw) {
        ""
    }
    else {
        $currentRaw.Trim()
    }
    if ($current -ne $BadContext) {
        return
    }

    $ctxs = Get-KubeconfigNameListSafe -KubeconfigPath $KubeconfigPath -KubectlArgs @("config", "get-contexts", "-o", "name")
    $fallback = $ctxs | Where-Object { $_ -ne $BadContext } | Select-Object -First 1
    if ($fallback) {
        [void](Invoke-KubectlUseContextSafe -KubeconfigPath $KubeconfigPath -Context $fallback -Retries 2)
    }
    else {
        Clear-KubeconfigCurrentContextSafe -KubeconfigPath $KubeconfigPath
    }
}
