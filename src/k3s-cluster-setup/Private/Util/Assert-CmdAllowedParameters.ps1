function Assert-CmdAllowedParameters {
    param(
        [Parameter(Mandatory)][string]$Command,
        [Parameter(Mandatory)][System.Collections.IDictionary]$BoundParameters
    )

    $common = @(
        'UiScriptName',
        'Verbose', 'Debug',
        'ErrorAction', 'ErrorVariable',
        'WarningAction', 'WarningVariable',
        'InformationAction', 'InformationVariable',
        'OutVariable', 'OutBuffer',
        'PipelineVariable',
        'ProgressAction', 'WhatIf', 'Confirm'
    )

    $createOpts = @(
        'Interactive', 'ClusterName', 'NoKubeconfig', 'MergeKubeconfig', 'KubeconfigName', 'MergedKubeconfigName',
        'Image', 'ServerCount', 'AgentCount', 'ServerCpu', 'AgentCpu', 'ServerDisk', 'AgentDisk', 'ServerMemory', 'AgentMemory',
        'Channel', 'K3sVersion', 'ServerToken', 'AgentToken', 'DisableFlannel', 'Minimal', 'DisableTraefik', 'DisableServiceLB', 'DisableMetricsServer',
        'OutputDir', 'KeepCloudInit', 'LaunchTimeoutSeconds', 'RemoteCmdTimeoutSeconds', 'ApiReadyTimeoutSeconds', 'NodeRegisterTimeoutSeconds', 'NodeReadyTimeoutSeconds'
    )

    $allowed = switch ($Command) {
        'help' { @('Command') }
        'list' { @('Command') }
        'listall' { @('Command') }
        'stop' { @('Command', 'ClusterName', 'Force', 'All') }
        'start' { @('Command', 'ClusterName', 'Force', 'All') }
        'delete' { @('Command', 'ClusterName', 'PurgeFiles', 'PurgeMultipass', 'Force', 'All') }
        'deletenode' { @('Command', 'ClusterName', 'NodeName', 'PurgeFiles', 'PurgeMultipass', 'Force') }
        'usecontext' { @('Command', 'ClusterName', 'MergedKubeconfigName') }
        'create' { @('Command') + $createOpts }
        'interactive' { @('Command') + $createOpts }
        default { throw "Unknown command '$Command'." }
    }

    $extra = @($BoundParameters.Keys | Where-Object { $_ -notin $allowed -and $_ -notin $common })
    if ($extra.Count -gt 0) {
        $fmt = ($extra | Sort-Object | ForEach-Object { "-$_" }) -join ", "
        throw ("Command '{0}' does not accept option(s): {1}" -f $Command, $fmt)
    }
}
