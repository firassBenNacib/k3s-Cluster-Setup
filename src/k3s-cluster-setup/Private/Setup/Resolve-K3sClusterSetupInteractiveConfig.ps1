function Resolve-K3sClusterSetupInteractiveConfig {
    [CmdletBinding(PositionalBinding = $true)]
    param(
        [Parameter(Mandatory)][string]$MultipassCmd,
        [Parameter(Mandatory)]$Config,
        [switch]$ClusterNameProvided
    )

    $promptClusterName = if ($ClusterNameProvided -and -not [string]::IsNullOrWhiteSpace($Config.ClusterName)) {
        $Config.ClusterName
    }
    else {
        ""
    }

    $cfg = Show-InteractivePrompts -MultipassCmd $MultipassCmd `
        -ClusterName $promptClusterName `
        -ClusterNameWasProvided:$ClusterNameProvided `
        -Channel $Config.Channel `
        -K3sVersion $Config.K3sVersion `
        -Image $Config.Image `
        -ServerCount $Config.ServerCount `
        -AgentCount $Config.AgentCount `
        -ServerCpu $Config.ServerCpu `
        -AgentCpu $Config.AgentCpu `
        -ServerDisk $Config.ServerDisk `
        -AgentDisk $Config.AgentDisk `
        -ServerMemory $Config.ServerMemory `
        -AgentMemory $Config.AgentMemory `
        -DisableFlannel:([bool]$Config.DisableFlannel) `
        -SaveKubeconfig:([bool]$Config.SaveKubeconfig) `
        -NoKubeconfig:([bool]$Config.NoKubeconfig) `
        -MergeKubeconfig:([bool]$Config.MergeKubeconfig) `
        -KubeconfigName $Config.KubeconfigName `
        -MergedKubeconfigName $Config.MergedKubeconfigName `
        -KeepCloudInit:([bool]$Config.KeepCloudInit) `
        -OutputDir $Config.OutputDir `
        -LaunchTimeoutSeconds $Config.LaunchTimeoutSeconds `
        -Minimal:([bool]$Config.Minimal) `
        -RemoteCmdTimeoutSeconds $Config.RemoteCmdTimeoutSeconds `
        -ApiReadyTimeoutSeconds $Config.ApiReadyTimeoutSeconds `
        -NodeRegisterTimeoutSeconds $Config.NodeRegisterTimeoutSeconds `
        -NodeReadyTimeoutSeconds $Config.NodeReadyTimeoutSeconds `
        -DisableTraefik:([bool]$Config.DisableTraefik) `
        -DisableServiceLB:([bool]$Config.DisableServiceLB) `
        -DisableMetricsServer:([bool]$Config.DisableMetricsServer)

    if (-not $cfg -or -not $cfg.Proceed) {
        return $null
    }

    $Config.ClusterName = $cfg.ClusterName
    $Config.Channel = $cfg.Channel
    $Config.K3sVersion = $cfg.K3sVersion
    $Config.Image = $cfg.Image
    $Config.ServerCount = $cfg.ServerCount
    $Config.AgentCount = $cfg.AgentCount
    $Config.ServerCpu = $cfg.ServerCpu
    $Config.AgentCpu = $cfg.AgentCpu
    $Config.ServerDisk = $cfg.ServerDisk
    $Config.AgentDisk = $cfg.AgentDisk
    $Config.ServerMemory = $cfg.ServerMemory
    $Config.AgentMemory = $cfg.AgentMemory
    $Config.DisableFlannel = [bool]$cfg.DisableFlannel

    $Config.SaveKubeconfig = [bool]$cfg.SaveKubeconfig
    $Config.NoKubeconfig = [bool]$cfg.NoKubeconfig
    $Config.MergeKubeconfig = [bool]$cfg.MergeKubeconfig
    $Config.KubeconfigName = $cfg.KubeconfigName
    $Config.MergedKubeconfigName = $cfg.MergedKubeconfigName
    $Config.OutputDir = $cfg.OutputDir
    $Config.KeepCloudInit = [bool]$cfg.KeepCloudInit

    $Config.LaunchTimeoutSeconds = $cfg.LaunchTimeoutSeconds
    $Config.Minimal = [bool]$cfg.Minimal
    $Config.RemoteCmdTimeoutSeconds = $cfg.RemoteCmdTimeoutSeconds
    $Config.ApiReadyTimeoutSeconds = $cfg.ApiReadyTimeoutSeconds
    $Config.NodeRegisterTimeoutSeconds = $cfg.NodeRegisterTimeoutSeconds
    $Config.NodeReadyTimeoutSeconds = $cfg.NodeReadyTimeoutSeconds
    $Config.DisableTraefik = [bool]$cfg.DisableTraefik
    $Config.DisableServiceLB = [bool]$cfg.DisableServiceLB
    $Config.DisableMetricsServer = [bool]$cfg.DisableMetricsServer

    $script:SaveKubeconfig = [bool]$Config.SaveKubeconfig

    return $Config
}
