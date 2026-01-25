function Resolve-K3sClusterSetupTargets {
    [CmdletBinding(PositionalBinding = $true)]
    param(
        [string]$ClusterName,
        [string[]]$Clusters,
        [Parameter(Mandatory)][string]$MultipassCmd
    )

    $targets = @()
    if ($Clusters -and $Clusters.Count -gt 0) {
        $targets += $Clusters
    }
    elseif (-not [string]::IsNullOrWhiteSpace($ClusterName)) {
        $targets += ($ClusterName -split '[,;]' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    }
    else {
        $picked = Select-ClusterPrompt -MultipassCmd $MultipassCmd
        if ([string]::IsNullOrWhiteSpace($picked)) {
            return @()
        }
        $targets += $picked
    }

    $targets = $targets |
        ForEach-Object { ConvertTo-ClusterName -Name $_ } |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        Select-Object -Unique

    return , @($targets)
}
