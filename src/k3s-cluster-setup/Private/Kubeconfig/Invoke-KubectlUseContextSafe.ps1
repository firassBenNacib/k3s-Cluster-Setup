function Invoke-KubectlUseContextSafe {
    param(
        [Parameter(Mandatory)][string]$KubeconfigPath,
        [Parameter(Mandatory)][string]$Context,
        [int]$Retries = 2
    )

    return Invoke-KubectlConfigCommandSafe -KubeconfigPath $KubeconfigPath -KubectlArgs @("config", "use-context", $Context) -Retries $Retries
}
