function Invoke-K3sClusterSetupCreate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$MultipassCmd,
        [string]$ClusterName,
        [switch]$ClusterNameProvided,
        [switch]$Interactive,
        [string]$Image,
        [int]$ServerCount,
        [int]$AgentCount,
        [string]$ServerCpu,
        [string]$AgentCpu,
        [string]$ServerDisk,
        [string]$AgentDisk,
        [string]$ServerMemory,
        [string]$AgentMemory,
        [string]$Channel,
        [AllowEmptyString()][string]$K3sVersion,
        [AllowEmptyString()][string]$ServerToken,
        [AllowEmptyString()][string]$AgentToken,
        [switch]$DisableFlannel,
        [switch]$Minimal,
        [switch]$DisableTraefik,
        [switch]$DisableServiceLB,
        [switch]$DisableMetricsServer,
        [switch]$NoKubeconfig,
        [switch]$MergeKubeconfig,
        [string]$KubeconfigName,
        [string]$MergedKubeconfigName,
        [string]$OutputDir,
        [switch]$KeepCloudInit,
        [int]$LaunchTimeoutSeconds,
        [int]$RemoteCmdTimeoutSeconds,
        [int]$ApiReadyTimeoutSeconds,
        [int]$NodeRegisterTimeoutSeconds,
        [int]$NodeReadyTimeoutSeconds
    )

    $config = [pscustomobject]@{
        ClusterName           = $ClusterName
        Image                 = $Image
        ServerCount           = $ServerCount
        AgentCount            = $AgentCount
        ServerCpu             = $ServerCpu
        AgentCpu              = $AgentCpu
        ServerDisk            = $ServerDisk
        AgentDisk             = $AgentDisk
        ServerMemory          = $ServerMemory
        AgentMemory           = $AgentMemory
        Channel               = $Channel
        K3sVersion            = $K3sVersion
        ServerToken           = $ServerToken
        AgentToken            = $AgentToken
        DisableFlannel        = [bool]$DisableFlannel
        Minimal               = [bool]$Minimal
        DisableTraefik        = [bool]$DisableTraefik
        DisableServiceLB      = [bool]$DisableServiceLB
        DisableMetricsServer  = [bool]$DisableMetricsServer
        NoKubeconfig          = [bool]$NoKubeconfig
        SaveKubeconfig        = [bool]$script:SaveKubeconfig
        MergeKubeconfig       = [bool]$MergeKubeconfig
        KubeconfigName        = $KubeconfigName
        MergedKubeconfigName  = $MergedKubeconfigName
        OutputDir             = $OutputDir
        KeepCloudInit         = [bool]$KeepCloudInit
        LaunchTimeoutSeconds  = $LaunchTimeoutSeconds
        RemoteCmdTimeoutSeconds = $RemoteCmdTimeoutSeconds
        ApiReadyTimeoutSeconds  = $ApiReadyTimeoutSeconds
        NodeRegisterTimeoutSeconds = $NodeRegisterTimeoutSeconds
        NodeReadyTimeoutSeconds    = $NodeReadyTimeoutSeconds
    }

    if ($Interactive) {
        $config = Resolve-K3sClusterSetupInteractiveConfig -MultipassCmd $MultipassCmd -Config $config -ClusterNameProvided:$ClusterNameProvided
        if (-not $config) {
            return
        }
    }

    $config = Resolve-K3sClusterSetupCreateOptions -MultipassCmd $MultipassCmd -Config $config
    if (-not $config) {
        return
    }

    New-K3sCluster -ClusterName $config.ClusterName `
        -Image (Expand-UserPath $config.Image) `
        -ServerCount $config.ServerCount `
        -AgentCount $config.AgentCount `
        -ServerCpu $config.ServerCpu `
        -AgentCpu $config.AgentCpu `
        -ServerDisk $config.ServerDisk `
        -AgentDisk $config.AgentDisk `
        -ServerMemory $config.ServerMemory `
        -AgentMemory $config.AgentMemory `
        -Channel $config.Channel `
        -K3sVersion $config.K3sVersion `
        -ServerToken $config.ServerToken `
        -AgentToken $config.AgentToken `
        -DisableFlannel:([bool]$config.DisableFlannel) `
        -MergeKubeconfig:([bool]$config.MergeKubeconfig) `
        -SaveKubeconfig:([bool]$config.SaveKubeconfig) `
        -KubeconfigName $config.KubeconfigName `
        -MergedKubeconfigName $config.MergedKubeconfigName `
        -KeepCloudInit:$config.KeepCloudInit `
        -OutputDir $config.OutputDir `
        -LaunchTimeoutSeconds $config.LaunchTimeoutSeconds `
        -Minimal:([bool]$config.Minimal) `
        -RemoteCmdTimeoutSeconds $config.RemoteCmdTimeoutSeconds `
        -ApiReadyTimeoutSeconds $config.ApiReadyTimeoutSeconds `
        -NodeRegisterTimeoutSeconds $config.NodeRegisterTimeoutSeconds `
        -NodeReadyTimeoutSeconds $config.NodeReadyTimeoutSeconds `
        -DisableTraefik:([bool]$config.DisableTraefik) `
        -DisableServiceLB:([bool]$config.DisableServiceLB) `
        -DisableMetricsServer:([bool]$config.DisableMetricsServer)
}
