function Test-IsClusterScopedMergedKubeconfig {
    param(
        [Parameter(Mandatory)][string]$MergedPath,
        [Parameter(Mandatory)][string]$ClusterName,
        [Parameter(Mandatory)][string]$CleanupDir
    )
    try {
        $mergedFull = [IO.Path]::GetFullPath((Expand-UserPath $MergedPath))
        $cleanupFull = [IO.Path]::GetFullPath((Expand-UserPath $CleanupDir))
        $leaf = Split-Path -Leaf $mergedFull
        $dir = Split-Path -Parent $mergedFull

        $clusterHit = ($leaf -match [regex]::Escape($ClusterName))
        $dirHit = $false
        if (-not [string]::IsNullOrWhiteSpace($cleanupFull)) {
            if ($dir -ieq $cleanupFull) {
                $dirHit = $true
            }
            elseif ($mergedFull.StartsWith($cleanupFull, [System.StringComparison]::OrdinalIgnoreCase)) {
                $dirHit = $true
            }
        }

        if ($clusterHit -or $dirHit) {
            return $true
        }
        return $false
    }
    catch {
        return $false
    }
}
