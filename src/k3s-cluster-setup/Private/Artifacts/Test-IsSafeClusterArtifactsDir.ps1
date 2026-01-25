function Test-IsSafeClusterArtifactsDir {
    param([Parameter(Mandatory)][string]$PathLike)

    $dir = Resolve-ExistingDirectoryPath -PathLike $PathLike
    if ([string]::IsNullOrWhiteSpace($dir)) {
        return $false
    }

    $marker = Get-ClusterArtifactsMarkerPath -ClusterDir $dir
    if (Test-Path -LiteralPath $marker) {
        return $true
    }

    $cluster = Split-Path -Leaf $dir
    if ([string]::IsNullOrWhiteSpace($cluster) -or ($cluster -ieq 'clusters')) {
        return $false
    }

    $pattern = "^$([regex]::Escape($cluster))-(kubeconfig|kubeconfig-orig|srv\d+-cloud-init|agt\d+-cloud-init)\.ya?ml$"
    try {
        foreach ($f in @(Get-ChildItem -LiteralPath $dir -File -ErrorAction SilentlyContinue)) {
            if ($f.Name -imatch $pattern) { return $true }
        }
    }
    catch {
        Write-NonFatalError $_
    }

    return $false
}
