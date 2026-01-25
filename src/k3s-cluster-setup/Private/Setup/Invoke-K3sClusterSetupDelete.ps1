function Invoke-K3sClusterSetupDelete {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory)][System.Management.Automation.PSCmdlet]$Cmdlet,
        [Parameter(Mandatory)][string]$MultipassCmd,
        [string]$ClusterName,
        [switch]$All,
        [switch]$Force,
        [switch]$PurgeFiles,
        [switch]$PurgeMultipass
    )

    if ($All) {
        if (-not $Cmdlet.ShouldProcess('ALL k3s clusters', 'Delete all clusters')) { return }
        Remove-AllK3sClusters -PurgeFiles:$PurgeFiles -PurgeMultipass:$PurgeMultipass -Force:$Force -Confirm:$false
        return
    }

    if ([string]::IsNullOrWhiteSpace($ClusterName)) {
        if ($WhatIfPreference) {
            $names = @(Get-ActiveClusterNames -MultipassCmd $MultipassCmd)
            if (-not $names -or $names.Count -eq 0) {
                Write-Host "No clusters found."
                return
            }
            Write-Host "Clusters:"
            foreach ($name in $names) {
                Write-Host ("  {0}" -f $name)
            }
            Write-Host "Specify cluster name to simulate deletion."
            return
        }
        $ClusterName = Select-ClusterPrompt -MultipassCmd $MultipassCmd
        if ([string]::IsNullOrWhiteSpace($ClusterName)) { return }
    }
    $ClusterName = ConvertTo-ClusterName -Name $ClusterName
    if (-not $Cmdlet.ShouldProcess($ClusterName, 'Delete cluster')) { return }
    Remove-K3sCluster -ClusterName $ClusterName -PurgeFiles:$PurgeFiles -PurgeMultipass:$PurgeMultipass -Force:$Force -Confirm:$false
}
