$script:StatePath = Resolve-StatePath -FileName ".k3s-multipass-cluster-manager.state.json"
$script:SaveKubeconfig = $true

$script:Limits = [ordered]@{
    ClusterNameMaxLen = 30
    ServerCountMin    = 0
    ServerCountMax    = 5
    AgentCountMin     = 0
    AgentCountMax     = 50
    CpuMin            = 1
    CpuMax            = 64
    MemoryMinBytes    = 512MB
    MemoryMaxBytes    = 64GB
    DiskMinBytes      = 5GB
    DiskMaxBytes      = 500GB
}
