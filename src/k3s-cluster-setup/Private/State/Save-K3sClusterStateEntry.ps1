function Save-K3sClusterStateEntry {
    [CmdletBinding(PositionalBinding = $true)]
    param(
        [Parameter(Mandatory)][string]$ClusterName,
        [string[]]$Servers,
        [string[]]$Agents,
        [Parameter(Mandatory)][string]$PrimaryServer,
        [Parameter(Mandatory)][string]$ServerIP,
        [AllowEmptyString()][string]$Kubeconfig,
        [AllowEmptyString()][string]$KubeconfigOrig,
        [AllowEmptyString()][string]$Merged,
        [Parameter(Mandatory)][string]$OutputDir,
        [Parameter(Mandatory)][bool]$OutputDirCreated
    )

    $entry = [pscustomobject]@{
        createdAt        = (Get-Date).ToString("s")
        servers          = $Servers
        agents           = $Agents
        primary          = $PrimaryServer
        serverIp         = $ServerIP
        kubeconfig       = $Kubeconfig
        kubeconfigOrig   = $KubeconfigOrig
        merged           = $Merged
        outputDir        = $OutputDir
        outputDirCreated = $OutputDirCreated
    }

    try {
        Set-ClusterState -name $ClusterName -entry $entry
    }
    catch {
        Write-Warning "Failed to save cluster state: $($_.Exception.Message)"
    }

    return $entry
}
