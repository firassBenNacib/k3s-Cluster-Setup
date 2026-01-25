function Clear-KubeconfigCurrentContextSafe {
    param([Parameter(Mandatory)][string]$KubeconfigPath)

    if (Get-Command kubectl -ErrorAction SilentlyContinue) {
        [void](Invoke-KubectlConfigCommandSafe -KubeconfigPath $KubeconfigPath -KubectlArgs @("config", "unset", "current-context") -Retries 2)
    }

    [void](Set-KubeconfigCurrentContext -Path $KubeconfigPath -Context "")
}
