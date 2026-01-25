function Get-UserKubeconfigFilePath {
    $dir = Join-Path $HOME ".kube"
    return (Join-Path $dir "config")
}
