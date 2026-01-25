function Show-Help {
    $usage = $ScriptName
    if (-not [string]::IsNullOrWhiteSpace($usage) -and $usage.ToLowerInvariant().EndsWith('.ps1')) {
        $usage = ".\$usage"
    }

    Write-Host @"
The k3s Cluster Manager for Multipass

USAGE:
    $usage <command> [cluster] [node] [options]

COMMANDS:
    create [cluster]                       Create a new k3s cluster
    interactive [cluster]                  Interactive create
    delete [cluster]                       Delete a cluster
    deletenode <cluster> [node]            Delete a specific node from a cluster
    stop [cluster]                         Stop a cluster
    start [cluster]                        Start a cluster
    list                                   List all k3s clusters
    listall                                List all Multipass VMs
    usecontext [context]                   Switch context in a merged kubeconfig
    help                                   Show this help message

COMMON CREATE OPTIONS:
    -Image <release/alias>                 Ubuntu image
    -Channel <name>                        k3s channel
    -ServerCount <n>                       Additional server instances
    -AgentCount <n>                        Worker instances
    -ServerCpu <n>                         CPU cores per server
    -AgentCpu <n>                          CPU cores per agent
    -ServerMemory <size>                   Memory per server
    -AgentMemory <size>                    Memory per agent
    -ServerDisk <size>                     Disk per server
    -AgentDisk <size>                      Disk per agent
    -DisableFlannel                        Disable Flannel CNI
    -Minimal                               Disable Traefik, ServiceLB and metrics-server
    -OutputDir <path>                      Directory for generated files
    -KeepCloudInit                         Keep cloud-init YAML files
    -NoKubeconfig                          Skip writing kubeconfig locally

ADVANCED CREATE OPTIONS:
    -K3sVersion <version>                  Pin k3s version
    -ServerToken <token>                   k3s server token
    -AgentToken <token>                    k3s agent token
    -DisableTraefik                        Disable Traefik
    -DisableServiceLB                      Disable ServiceLB
    -DisableMetricsServer                  Disable metrics-server
    -MergeKubeconfig                       Build/refresh a merged kubeconfig file
    -KubeconfigName <name/path>            Kubeconfig output name/path
    -MergedKubeconfigName <name/path>      Output name/path for merged kubeconfig
    -LaunchTimeoutSeconds <n>              Multipass launch timeout
    -RemoteCmdTimeoutSeconds <n>           Remote command timeout
    -ApiReadyTimeoutSeconds <n>            k3s API readiness timeout
    -NodeRegisterTimeoutSeconds <n>        Node registration timeout
    -NodeReadyTimeoutSeconds <n>           Node readiness timeout

DELETE OPTIONS:
    -All                                  Target all clusters (delete/stop/start)
    -PurgeFiles                            Remove local artifacts on delete
    -PurgeMultipass                        Purge deleted instances from Multipass cache
    -Force                                 Skip interactive prompts

SAFETY / COMMON PARAMETERS:
    -WhatIf                                Show what would happen without changing anything
    -Confirm                               Prompt before performing state-changing actions
    -Verbose                               Show additional diagnostics

ENV:
    K3S_CLUSTER_SETUP_STATE                Path to state file or directory to store it
"@
}
