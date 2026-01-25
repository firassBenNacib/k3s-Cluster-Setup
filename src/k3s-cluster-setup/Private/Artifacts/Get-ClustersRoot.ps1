function Get-ClustersRoot {

    $base = Get-DefaultArtifactsRoot
    $clustersRoot = Join-Path $base 'clusters'

    try {
        if (-not (Test-Path -LiteralPath $clustersRoot)) {
            New-Item -ItemType Directory -Path $clustersRoot -Force | Out-Null
        }
    }
    catch {

        $clustersRoot = $base
    }

    return $clustersRoot
}
