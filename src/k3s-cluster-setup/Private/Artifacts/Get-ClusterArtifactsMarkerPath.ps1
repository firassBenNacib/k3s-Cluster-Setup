function Get-ClusterArtifactsMarkerPath {
    param([Parameter(Mandatory)][string]$ClusterDir)

    return (Join-Path $ClusterDir '.k3s-multipass-cluster-manager.cluster')
}
