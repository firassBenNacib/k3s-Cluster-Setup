function Invoke-KubectlConfigCommandSafe {
    param(
        [Parameter(Mandatory)][string]$KubeconfigPath,
        [Parameter(Mandatory)][string[]]$KubectlArgs,
        [int]$Retries = 2
    )

    if (-not (Get-Command kubectl -ErrorAction SilentlyContinue)) {
        return $false
    }

    for ($i = 0; $i -lt $Retries; $i++) {
        [void](Clear-KubeconfigLockFiles -CandidateKubeconfigPaths @($KubeconfigPath) -WaitSeconds 5)
        $result = Invoke-NativeCommandSafe -FilePath "kubectl" -CommandArgs (@("--kubeconfig", $KubeconfigPath) + $KubectlArgs)
        if ($result.ExitCode -eq 0) {
            return $true
        }
        if ($result.Output -notmatch 'config\.lock') {
            return $false
        }
        Start-Sleep -Milliseconds 300
    }

    return $false
}
