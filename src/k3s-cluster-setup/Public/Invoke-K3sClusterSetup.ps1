function Invoke-K3sClusterSetup {
    [CmdletBinding(PositionalBinding = $false, SupportsShouldProcess = $true)]
    param(

        [Parameter(Mandatory = $false)]
        [AllowEmptyString()]
        [string]$UiScriptName = "",

        [Parameter(Mandatory = $false, Position = 0)]
        [ValidateSet('create', 'interactive', 'delete', 'deletenode', 'stop', 'start', 'list', 'listall', 'usecontext', 'help')]
        [string]$Command = 'help',

        [Parameter(Mandatory = $false, Position = 1)]
        [string]$ClusterName = "",

        [Parameter(Mandatory = $false)]
        [string[]]$Clusters = @(),

        [Parameter(Mandatory = $false, Position = 2)]
        [string]$NodeName = "",

        [Parameter(Mandatory = $false)]
        [switch]$Interactive,

        [Parameter(Mandatory = $false)]
        [switch]$NoKubeconfig,

        [Parameter(Mandatory = $false)]
        [switch]$MergeKubeconfig,

        [Parameter(Mandatory = $false)]
        [string]$KubeconfigName = "",

        [Parameter(Mandatory = $false)]
        [string]$OutputDir = "",

        [Parameter(Mandatory = $false)]
        [switch]$KeepCloudInit,

        [Parameter(Mandatory = $false)]
        [string]$MergedKubeconfigName = "",

        [Parameter(Mandatory = $false)]
        [switch]$PurgeFiles,

        [Parameter(Mandatory = $false)]
        [switch]$PurgeMultipass,

        [Parameter(Mandatory = $false)]
        [switch]$Force,

        [Parameter(Mandatory = $false)]
        [switch]$All,

        [Parameter(Mandatory = $false)]
        [string]$Image = "",

        [Parameter(Mandatory = $false)]
        [int]$ServerCount = -1,

        [Parameter(Mandatory = $false)]
        [int]$AgentCount = -1,

        [Parameter(Mandatory = $false)]
        [string]$ServerCpu = "",

        [Parameter(Mandatory = $false)]
        [string]$AgentCpu = "",

        [Parameter(Mandatory = $false)]
        [string]$ServerDisk = "",

        [Parameter(Mandatory = $false)]
        [string]$AgentDisk = "",

        [Parameter(Mandatory = $false)]
        [string]$ServerMemory = "",

        [Parameter(Mandatory = $false)]
        [string]$AgentMemory = "",

        [Parameter(Mandatory = $false)]
        [string]$Channel = "stable",

        [Parameter(Mandatory = $false)]
        [AllowEmptyString()]
        [string]$K3sVersion = "",

        [Parameter(Mandatory = $false)]
        [AllowEmptyString()]
        [string]$ServerToken = "",

        [Parameter(Mandatory = $false)]
        [AllowEmptyString()]
        [string]$AgentToken = "",

        [Parameter(Mandatory = $false)]
        [switch]$DisableFlannel,

        [Parameter(Mandatory = $false)]
        [switch]$Minimal,

        [Parameter(Mandatory = $false)]
        [switch]$DisableTraefik,

        [Parameter(Mandatory = $false)]
        [switch]$DisableServiceLB,

        [Parameter(Mandatory = $false)]
        [switch]$DisableMetricsServer,

        [Parameter(Mandatory = $false)]
        [int]$LaunchTimeoutSeconds = 900,

        [Parameter(Mandatory = $false)]
        [int]$RemoteCmdTimeoutSeconds = 20,

        [Parameter(Mandatory = $false)]
        [int]$ApiReadyTimeoutSeconds = 900,

        [Parameter(Mandatory = $false)]
        [int]$NodeRegisterTimeoutSeconds = 900,

        [Parameter(Mandatory = $false)]
        [int]$NodeReadyTimeoutSeconds = 1800
    )

    try {
        if (-not [string]::IsNullOrWhiteSpace($UiScriptName)) {
            $script:ScriptName = $UiScriptName
        }
        elseif ($MyInvocation -and $MyInvocation.MyCommand -and $MyInvocation.MyCommand.CommandType -eq 'Function') {
            $script:ScriptName = $MyInvocation.MyCommand.Name
        }
        elseif ($PSCommandPath) {
            $script:ScriptName = (Split-Path -Leaf $PSCommandPath)
        }
        elseif (-not (Get-Variable -Scope Script -Name ScriptName -ErrorAction SilentlyContinue)) {
            $script:ScriptName = "k3s-cluster-setup.ps1"
        }
    }
    catch { }

    $c = $Command.Trim().ToLowerInvariant()

    if ($c -eq 'interactive') {
        $Interactive = $true; $c = 'create'
    }
    $bp = @{} + $PSBoundParameters; $null = $bp.Remove("UiScriptName"); Assert-CmdAllowedParameters -Command $c -BoundParameters $bp

    if ($c -eq 'help') {
        Show-Help; return
    }

    if ($c -eq 'create' -and $WhatIfPreference) {
        $target = ""
        if (-not [string]::IsNullOrWhiteSpace($ClusterName)) {
            $target = ConvertTo-ClusterName -Name $ClusterName
        }
        if ([string]::IsNullOrWhiteSpace($target)) {
            $target = "<auto>"
        }
        $null = $PSCmdlet.ShouldProcess($target, 'Create cluster')
        return
    }

    $multipass = Get-MultipassCmd

    switch ($c) {
        'listall' {
            Invoke-K3sClusterSetupListAll -MultipassCmd $multipass
            return
        }
        'list' {
            Invoke-K3sClusterSetupList -MultipassCmd $multipass
            return
        }
        'stop' {
            Invoke-K3sClusterSetupStop -Cmdlet $PSCmdlet -MultipassCmd $multipass -ClusterName $ClusterName -Clusters $Clusters -All:$All -Force:$Force
            return
        }

        'start' {
            Invoke-K3sClusterSetupStart -Cmdlet $PSCmdlet -MultipassCmd $multipass -ClusterName $ClusterName -Clusters $Clusters -All:$All -Force:$Force
            return
        }

        'deletenode' {
            Invoke-K3sClusterSetupDeleteNode -Cmdlet $PSCmdlet -MultipassCmd $multipass -ClusterName $ClusterName -NodeName $NodeName -Force:$Force -PurgeFiles:$PurgeFiles -PurgeMultipass:$PurgeMultipass
            return
        }
        'delete' {
            Invoke-K3sClusterSetupDelete -Cmdlet $PSCmdlet -MultipassCmd $multipass -ClusterName $ClusterName -All:$All -Force:$Force -PurgeFiles:$PurgeFiles -PurgeMultipass:$PurgeMultipass
            return
        }
        'usecontext' {
            Invoke-K3sClusterSetupUseContext -MultipassCmd $multipass -ClusterName $ClusterName -MergedKubeconfigName $MergedKubeconfigName
            return
        }
        'create' {
        }
        default {
            Show-Help
            return
        }
    }

    $clusterNameProvided = ($PSBoundParameters.ContainsKey('ClusterName') -and -not [string]::IsNullOrWhiteSpace($ClusterName))
    Invoke-K3sClusterSetupCreate -MultipassCmd $multipass `
        -ClusterName $ClusterName `
        -ClusterNameProvided:$clusterNameProvided `
        -Interactive:$Interactive `
        -Image $Image `
        -ServerCount $ServerCount `
        -AgentCount $AgentCount `
        -ServerCpu $ServerCpu `
        -AgentCpu $AgentCpu `
        -ServerDisk $ServerDisk `
        -AgentDisk $AgentDisk `
        -ServerMemory $ServerMemory `
        -AgentMemory $AgentMemory `
        -Channel $Channel `
        -K3sVersion $K3sVersion `
        -ServerToken $ServerToken `
        -AgentToken $AgentToken `
        -DisableFlannel:$DisableFlannel `
        -Minimal:$Minimal `
        -DisableTraefik:$DisableTraefik `
        -DisableServiceLB:$DisableServiceLB `
        -DisableMetricsServer:$DisableMetricsServer `
        -NoKubeconfig:$NoKubeconfig `
        -MergeKubeconfig:$MergeKubeconfig `
        -KubeconfigName $KubeconfigName `
        -MergedKubeconfigName $MergedKubeconfigName `
        -OutputDir $OutputDir `
        -KeepCloudInit:$KeepCloudInit `
        -LaunchTimeoutSeconds $LaunchTimeoutSeconds `
        -RemoteCmdTimeoutSeconds $RemoteCmdTimeoutSeconds `
        -ApiReadyTimeoutSeconds $ApiReadyTimeoutSeconds `
        -NodeRegisterTimeoutSeconds $NodeRegisterTimeoutSeconds `
        -NodeReadyTimeoutSeconds $NodeReadyTimeoutSeconds

    return
}
