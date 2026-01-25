function Test-IsKubeconfigFile {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        return $false
    }
    $raw = Get-Content -LiteralPath $Path -Raw -ErrorAction SilentlyContinue
    if ([string]::IsNullOrWhiteSpace($raw)) {
        return $false
    }

    $hasClusters = ($raw -match '(?m)^\s*clusters:\s*(\[\]\s*)?(null\s*)?$')
    $hasContexts = ($raw -match '(?m)^\s*contexts:\s*(\[\]\s*)?(null\s*)?$')
    $hasUsers = ($raw -match '(?m)^\s*users:\s*(\[\]\s*)?(null\s*)?$')

    if (-not $hasClusters) {
        $hasClusters = ($raw -match '(?m)^\s*clusters:\s*$')
    }
    if (-not $hasContexts) {
        $hasContexts = ($raw -match '(?m)^\s*contexts:\s*$')
    }
    if (-not $hasUsers) {
        $hasUsers = ($raw -match '(?m)^\s*users:\s*$')
    }

    return $hasClusters -and $hasContexts -and $hasUsers
}
