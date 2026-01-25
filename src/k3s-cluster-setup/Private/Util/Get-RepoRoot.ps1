function Get-RepoRoot {

    if (-not [string]::IsNullOrWhiteSpace($env:K3S_CLUSTER_SETUP_REPO_ROOT)) {
        try {
            return (Resolve-OutputDirectory -PathLike $env:K3S_CLUSTER_SETUP_REPO_ROOT)
        }
        catch {
            return $null
        }
    }

    if ($script:RepoRoot) {
        return $script:RepoRoot
    }

    $moduleRoot = $script:ModuleRoot
    if ([string]::IsNullOrWhiteSpace($moduleRoot)) {
        $moduleRoot = $PSScriptRoot
    }

    try {
        $srcDir = Split-Path -Parent $moduleRoot
        $repoDir = Split-Path -Parent $srcDir
        if (-not [string]::IsNullOrWhiteSpace($repoDir)) {
            $hasSrc = Test-Path -LiteralPath (Join-Path $repoDir 'src')
            $hasScripts = Test-Path -LiteralPath (Join-Path $repoDir 'scripts')
            if ($hasSrc -and $hasScripts) {
                $script:RepoRoot = (Resolve-Path -LiteralPath $repoDir).Path
                return $script:RepoRoot
            }
        }
    }
    catch {
        Write-NonFatalError $_
    }

    return $null
}
