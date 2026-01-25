function Remove-KubeconfigEntries {
    param(
        [Parameter(Mandatory)][string]$KubeconfigPath,
        [Parameter(Mandatory)][string]$ClusterName
    )
    if (-not (Get-Command kubectl -ErrorAction SilentlyContinue)) {
        return
    }
    if (-not (Test-Path -LiteralPath $KubeconfigPath)) {
        return
    }

    $cfg = Get-KubeconfigJson -KubeconfigPath $KubeconfigPath
    $isManagedHere = $false
    try {
        foreach ($ctx in @(ConvertTo-Array $cfg.contexts)) {
            if ($null -eq $ctx) {
                continue
            }
            $n = [string]$ctx.name
            $c = [string]$ctx.context.cluster
            $u = [string]$ctx.context.user
            if ($n -eq $ClusterName -and $c -eq $ClusterName -and $u -eq $ClusterName) {
                $isManagedHere = $true
                break
            }
        }
    }
    catch {
        $isManagedHere = $false
    }

    if (-not $isManagedHere) {
        return
    }

    foreach ($kubectlArgs in @(
            @("config", "delete-context", $ClusterName),
            @("config", "delete-cluster", $ClusterName),
            @("config", "delete-user", $ClusterName)
        )) {
        [void](Invoke-KubectlConfigCommandSafe -KubeconfigPath $KubeconfigPath -KubectlArgs $kubectlArgs -Retries 2)
    }
}
