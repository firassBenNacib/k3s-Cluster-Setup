function New-K3sCluster {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory)][string]$ClusterName,
        [Parameter(Mandatory)][string]$Image,
        [Parameter(Mandatory)][int]$ServerCount,
        [Parameter(Mandatory)][int]$AgentCount,
        [Parameter(Mandatory)][string]$ServerCpu,
        [Parameter(Mandatory)][string]$AgentCpu,
        [Parameter(Mandatory)][string]$ServerDisk,
        [Parameter(Mandatory)][string]$AgentDisk,
        [Parameter(Mandatory)][string]$ServerMemory,
        [Parameter(Mandatory)][string]$AgentMemory,
        [Parameter(Mandatory)][string]$Channel,
        [AllowEmptyString()][string]$K3sVersion,
        [AllowEmptyString()][string]$ServerToken,
        [AllowEmptyString()][string]$AgentToken,
        [Parameter(Mandatory)][bool]$DisableFlannel,
        [Parameter(Mandatory)][bool]$MergeKubeconfig,
        [Parameter(Mandatory)][bool]$SaveKubeconfig,
        [AllowEmptyString()][string]$KubeconfigName,
        [AllowEmptyString()][string]$MergedKubeconfigName,
        [Parameter(Mandatory)][string]$OutputDir,
        [Parameter(Mandatory = $false)]
        [switch]$KeepCloudInit,
        [Parameter(Mandatory)][int]$LaunchTimeoutSeconds,
        [Parameter(Mandatory)][bool]$Minimal,
        [int]$RemoteCmdTimeoutSeconds,
        [int]$ApiReadyTimeoutSeconds,
        [int]$NodeRegisterTimeoutSeconds,
        [int]$NodeReadyTimeoutSeconds,
        [bool]$DisableTraefik,
        [bool]$DisableServiceLB,
        [bool]$DisableMetricsServer
    )

    if (-not $PSCmdlet.ShouldProcess($ClusterName, 'Create cluster')) {
        return
    }

    $ctx = Initialize-NewK3sClusterContext -ClusterName $ClusterName -OutputDir $OutputDir -ServerCount $ServerCount
    $OutputDir = $ctx.OutputDir
    $outputDirCreated = [bool]$ctx.OutputDirCreated
    $multipass = $ctx.MultipassCmd
    $useClusterInit = $ctx.UseClusterInit
    $origKubeEnv = $ctx.OrigKubeEnv
    $cancelHandler = $ctx.CancelHandler
    $createdVms = $ctx.CreatedVms
    $createdFiles = $ctx.CreatedFiles
    $plannedVms = $ctx.PlannedVms

    if ([string]::IsNullOrEmpty($ServerToken)) {
        $ServerToken = New-RandomString -Length 20
        Write-Verbose "Generated server token."
    }
    if ([string]::IsNullOrEmpty($AgentToken)) {
        $AgentToken = $ServerToken
        Write-Verbose "Using agent token = server token."
    }

    if ($Minimal) {
        $DisableTraefik = $true
        $DisableServiceLB = $true
        $DisableMetricsServer = $true
    }

    $success = $false
    $err = $null

    $servers = @()
    $agents = @()
    $serverIP = ""
    $plan = Get-K3sClusterVmPlan -ClusterName $ClusterName -ServerCount $ServerCount -AgentCount $AgentCount
    $server1 = $plan.PrimaryServer
    $additionalServers = @($plan.ServerNames | Select-Object -Skip 1)
    $agentNames = @($plan.AgentNames)
    $kubeconfigOrig = $null

    try {
        Stop-IfCancelled
        Write-Host ""
        $verDisp = if ([string]::IsNullOrWhiteSpace($K3sVersion)) { "" } else { " ($K3sVersion)" }
        $flannelDisp = if ($DisableFlannel) { "off" } else { "on" }

        Show-CancelHint
        Write-Verbose ("Plan: srv={0} wkr={1} img={2} k3s={3}{4} flannel={5}" -f ($ServerCount + 1), $AgentCount, $Image, $Channel, $verDisp, $flannelDisp)

        $serverResult = Invoke-K3sClusterCreateServers -ClusterName $ClusterName `
            -PrimaryServer $server1 `
            -AdditionalServers $additionalServers `
            -Image $Image `
            -ServerCpu $ServerCpu `
            -ServerDisk $ServerDisk `
            -ServerMemory $ServerMemory `
            -Channel $Channel `
            -K3sVersion $K3sVersion `
            -ServerToken $ServerToken `
            -AgentToken $AgentToken `
            -DisableFlannel:([bool]$DisableFlannel) `
            -DisableTraefik:([bool]$DisableTraefik) `
            -DisableServiceLB:([bool]$DisableServiceLB) `
            -DisableMetricsServer:([bool]$DisableMetricsServer) `
            -OutputDir $OutputDir `
            -MultipassCmd $multipass `
            -LaunchTimeoutSeconds $LaunchTimeoutSeconds `
            -RemoteCmdTimeoutSeconds $RemoteCmdTimeoutSeconds `
            -ApiReadyTimeoutSeconds $ApiReadyTimeoutSeconds `
            -NodeRegisterTimeoutSeconds $NodeRegisterTimeoutSeconds `
            -NodeReadyTimeoutSeconds $NodeReadyTimeoutSeconds `
            -UseClusterInit:([bool]$useClusterInit) `
            -CreatedVms $createdVms `
            -CreatedFiles $createdFiles `
            -PlannedVms $plannedVms

        $servers = @($serverResult.Servers)
        $serverIP = $serverResult.ServerIP

        $agents = Invoke-K3sClusterCreateAgents -ClusterName $ClusterName `
            -PrimaryServer $server1 `
            -AgentNames $agentNames `
            -Image $Image `
            -AgentCpu $AgentCpu `
            -AgentDisk $AgentDisk `
            -AgentMemory $AgentMemory `
            -Channel $Channel `
            -K3sVersion $K3sVersion `
            -ServerToken $ServerToken `
            -AgentToken $AgentToken `
            -ServerIP $serverIP `
            -OutputDir $OutputDir `
            -MultipassCmd $multipass `
            -LaunchTimeoutSeconds $LaunchTimeoutSeconds `
            -RemoteCmdTimeoutSeconds $RemoteCmdTimeoutSeconds `
            -NodeRegisterTimeoutSeconds $NodeRegisterTimeoutSeconds `
            -NodeReadyTimeoutSeconds $NodeReadyTimeoutSeconds `
            -DisableFlannel:([bool]$DisableFlannel) `
            -CreatedVms $createdVms `
            -CreatedFiles $createdFiles `
            -PlannedVms $plannedVms

        Stop-IfCancelled

        $kc = Invoke-K3sClusterKubeconfigSetup -ClusterName $ClusterName `
            -ServerName $server1 `
            -ServerIP $serverIP `
            -OutputDir $OutputDir `
            -KubeconfigName $KubeconfigName `
            -MergedKubeconfigName $MergedKubeconfigName `
            -SaveKubeconfig:([bool]$SaveKubeconfig) `
            -MergeKubeconfig:([bool]$MergeKubeconfig) `
            -MultipassCmd $multipass `
            -RemoteCmdTimeoutSeconds $RemoteCmdTimeoutSeconds `
            -OrigKubeEnv $origKubeEnv `
            -CreatedFiles $createdFiles

        $kubeconfigFile = $kc.KubeconfigFile
        $kubeconfigOrig = $kc.KubeconfigOrig
        $mergedOut = $kc.MergedOut

        Stop-IfCancelled
        Save-K3sClusterStateEntry -ClusterName $ClusterName `
            -Servers $servers `
            -Agents $agents `
            -PrimaryServer $server1 `
            -ServerIP $serverIP `
            -Kubeconfig $kubeconfigFile `
            -KubeconfigOrig $kubeconfigOrig `
            -Merged $mergedOut `
            -OutputDir $OutputDir `
            -OutputDirCreated:$outputDirCreated | Out-Null

        if (-not $KeepCloudInit) {
            Remove-K3sClusterCloudInitFiles -CreatedFiles $createdFiles
        }

        $success = $true
        Write-Host ""
        Write-Host "Setup Complete" -ForegroundColor Green
        return
    }
    catch {
        $err = $_
    }
    finally {
        Disable-CancelHandler -Handler $cancelHandler
        if (-not $success) {
            Invoke-K3sClusterCreateCleanup -ClusterName $ClusterName -OutputDir $OutputDir -OutputDirCreated:$outputDirCreated -MultipassCmd $multipass -CreatedVms $createdVms -PlannedVms $plannedVms -CreatedFiles $createdFiles -ErrorRecord $err
        }
        $script:CancelRequested = $false
        $global:K3S_CLUSTER_SETUP_CANCEL_REQUESTED = $false
    }

    if (-not $success) {
        if ($err) {
            throw $err
        }
        throw "Create failed."
    }
}
