function Invoke-KubectlConfigReadSafe {
    param(
        [Parameter(Mandatory)][string]$KubeconfigPath,
        [Parameter(Mandatory)][string[]]$KubectlArgs,
        [int]$Retries = 2
    )

    if (-not (Get-Command kubectl -ErrorAction SilentlyContinue)) {
        return $null
    }

    for ($i = 0; $i -lt $Retries; $i++) {
        [void](Clear-KubeconfigLockFiles -CandidateKubeconfigPaths @($KubeconfigPath) -WaitSeconds 5)
        $result = Invoke-NativeCommandSafe -FilePath "kubectl" -CommandArgs (@("--kubeconfig", $KubeconfigPath) + $KubectlArgs)
        if ($result.ExitCode -eq 0) {
            return $result.Output
        }
        if ($result.Output -notmatch 'config\.lock') {
            return $null
        }
        Start-Sleep -Milliseconds 300
    }

    return $null
}
