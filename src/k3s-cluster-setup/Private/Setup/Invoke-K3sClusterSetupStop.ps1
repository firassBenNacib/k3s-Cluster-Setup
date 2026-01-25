function Invoke-K3sClusterSetupStop {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory)][System.Management.Automation.PSCmdlet]$Cmdlet,
        [Parameter(Mandatory)][string]$MultipassCmd,
        [string]$ClusterName,
        [string[]]$Clusters,
        [switch]$All,
        [switch]$Force
    )

    if ($All) {
        if (-not $Cmdlet.ShouldProcess('ALL k3s clusters', 'Stop all clusters')) { return }
        Stop-AllK3sClusters -Force:$Force -Confirm:$false
        return
    }

    $targets = Resolve-K3sClusterSetupTargets -ClusterName $ClusterName -Clusters $Clusters -MultipassCmd $MultipassCmd
    if (-not $targets -or $targets.Count -eq 0) {
        return
    }

    $inv = Get-ClusterInventory -MultipassCmd $MultipassCmd
    $names = @((ConvertTo-Array $inv.Names))
    if ($names.Count -eq 0) {
        Write-Host "No clusters found." -ForegroundColor Yellow
        return
    }

    foreach ($c in $targets) {
        if ($names -notcontains $c) {
            Write-Host "Cluster '$c' not found." -ForegroundColor Yellow
            continue
        }
        if (-not $Cmdlet.ShouldProcess($c, 'Stop cluster')) { continue }
        $null = Stop-K3sCluster -ClusterName $c -Force:$Force -Confirm:$false
    }
}
