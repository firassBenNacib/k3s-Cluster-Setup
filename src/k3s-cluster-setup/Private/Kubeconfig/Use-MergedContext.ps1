function Use-MergedContext {
    param([string]$ClusterName, [string]$MergedPath)
    if (-not (Get-Command kubectl -ErrorAction SilentlyContinue)) {
        throw "kubectl not found in PATH."
    }
    if (-not (Invoke-KubectlUseContextSafe -KubeconfigPath $MergedPath -Context $ClusterName -Retries 2)) {
        throw "Failed to switch context to '$ClusterName' in '$MergedPath'."
    }
    Write-Host "Current context: $ClusterName" -ForegroundColor Green
}
