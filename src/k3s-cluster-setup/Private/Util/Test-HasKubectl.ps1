function Test-HasKubectl {
    return [bool](Get-Command kubectl -ErrorAction SilentlyContinue)
}
