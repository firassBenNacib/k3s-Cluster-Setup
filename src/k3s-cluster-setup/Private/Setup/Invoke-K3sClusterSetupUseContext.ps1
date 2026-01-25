function Invoke-K3sClusterSetupUseContext {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$MultipassCmd,
        [string]$ClusterName,
        [string]$MergedKubeconfigName
    )

    $merged = Resolve-MergedKubeconfigForUse -PathLike $MergedKubeconfigName -ClusterName $ClusterName
    $ctx = $ClusterName
    if ([string]::IsNullOrWhiteSpace($ctx)) {
        $ctx = Select-ContextPrompt -MergedPath $merged
        if ([string]::IsNullOrWhiteSpace($ctx)) {
            return
        }
    }
    else {
        $contexts = @()
        try {
            $contexts = ConvertTo-Array (Get-KubeconfigContexts -MergedPath $merged)
        }
        catch {
            Write-Warning ("Failed to read contexts from '{0}': {1}" -f $merged, $_.Exception.Message)
            return
        }
        $ctxList = @($contexts)
        if ($ctxList.Count -eq 0) {
            Write-Host "No contexts found." -ForegroundColor Yellow
            return
        }
        if ($ctxList -notcontains $ctx) {
            Write-Host "Context '$ctx' not found." -ForegroundColor Yellow
            return
        }
    }

    try {
        $st = Get-State
        if ($st -and $st.clusters -and $st.clusters.ContainsKey($ctx)) {
            $primaryVm = $st.clusters[$ctx].primary
            $mp = Get-MultipassListJson -MultipassCmd $MultipassCmd
            $inst = $mp.list | Where-Object { $_.name -eq $primaryVm } | Select-Object -First 1
            if ($inst -and $inst.state -eq 'Running') {
                $null = Refresh-ClusterApiEndpoint -ClusterName $ctx -MultipassCmd $MultipassCmd
            }
        }
    }
    catch {
    }

    Use-MergedContext -ClusterName $ctx -MergedPath $merged
    $userCfg = Update-UserKubeconfigFromMerged -MergedPath $merged -PreferredContext $ctx
    $env:KUBECONFIG = $userCfg
}
