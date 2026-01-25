function Get-ClusterArtifactsDir {
    param(
        [Parameter(Mandatory)][string]$ClusterName,
        [string]$ArtifactsRoot
    )

    if ([string]::IsNullOrWhiteSpace($ArtifactsRoot)) {
        $clustersRoot = Get-ClustersRoot
    }
    else {
        $clustersRoot = Join-Path (Resolve-OutputDirectory -PathLike $ArtifactsRoot) 'clusters'
        if (-not (Test-Path -LiteralPath $clustersRoot)) {
            New-Item -ItemType Directory -Path $clustersRoot -Force | Out-Null
        }
    }

    $dir = Join-Path $clustersRoot $ClusterName
    if (-not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }

    return $dir
}
