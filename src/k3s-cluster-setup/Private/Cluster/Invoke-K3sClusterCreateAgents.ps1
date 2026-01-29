function Invoke-K3sClusterCreateAgents {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ClusterName,
        [Parameter(Mandatory)][string]$PrimaryServer,
        [string[]]$AgentNames = @(),
        [Parameter(Mandatory)][string]$Image,
        [Parameter(Mandatory)][string]$AgentCpu,
        [Parameter(Mandatory)][string]$AgentDisk,
        [Parameter(Mandatory)][string]$AgentMemory,
        [Parameter(Mandatory)][string]$Channel,
        [AllowEmptyString()][string]$K3sVersion,
        [Parameter(Mandatory)][string]$ServerToken,
        [Parameter(Mandatory)][string]$AgentToken,
        [Parameter(Mandatory)][string]$ServerIP,
        [Parameter(Mandatory)][string]$OutputDir,
        [Parameter(Mandatory)][string]$MultipassCmd,
        [Parameter(Mandatory)][int]$LaunchTimeoutSeconds,
        [Parameter(Mandatory)][int]$RemoteCmdTimeoutSeconds,
        [Parameter(Mandatory)][int]$NodeRegisterTimeoutSeconds,
        [Parameter(Mandatory)][int]$NodeReadyTimeoutSeconds,
        [Parameter(Mandatory)][bool]$DisableFlannel,
        [Parameter(Mandatory)][AllowEmptyCollection()][System.Collections.Generic.List[string]]$CreatedVms,
        [Parameter(Mandatory)][AllowEmptyCollection()][System.Collections.Generic.List[string]]$CreatedFiles,
        [Parameter(Mandatory)][AllowEmptyCollection()][System.Collections.Generic.List[string]]$PlannedVms
    )

    $agents = @()
    if (@($AgentNames).Count -eq 0) {
        return $agents
    }

    Write-Host ""
    Write-Host ("Creating {0} agent(s)..." -f @($AgentNames).Count) -ForegroundColor Green
    $serverIP = $ServerIP
    for ($i = 0; $i -lt @($AgentNames).Count; $i++) {
        Stop-IfCancelled
        $aname = $AgentNames[$i]
        $agentIndex = $i + 1
        try {
            $latestIp = Get-InstanceIPv4 -MultipassCmd $MultipassCmd -InstanceName $PrimaryServer
            if ($latestIp -and $latestIp -ne $serverIP) {
                Write-Verbose ("Server IP changed during create: '{0}' -> '{1}'" -f $serverIP, $latestIp)
                $serverIP = $latestIp
            }
        }
        catch {
            Write-Verbose ("Failed to refresh server IP for '{0}': {1}" -f $PrimaryServer, $_.Exception.Message)
        }
        $aci = New-CloudInitTemplate -Hostname $aname -Channel $Channel -K3sVersion $K3sVersion -ServerToken $ServerToken -AgentToken $AgentToken `
            -ServerIP $serverIP -IsAgent:$true -ServerExec "" -AgentExec "agent"

        $aciFile = Join-Path $OutputDir ("{0}-agt{1}-cloud-init.yaml" -f $ClusterName, $agentIndex)
        Write-Utf8File -Path $aciFile -Content $aci
        [void]$CreatedFiles.Add($aciFile)

        Write-Host "Creating agent: $aname" -ForegroundColor Green
        [void]$PlannedVms.Add($aname)
        Invoke-MultipassLaunchResilient -MultipassCmd $MultipassCmd -InstanceName $aname -MpArgs @(
            "launch", "--timeout", $LaunchTimeoutSeconds.ToString(),
            "--cpus", $AgentCpu, "--disk", $AgentDisk, "--memory", $AgentMemory,
            $Image, "--name", $aname, "--cloud-init", $aciFile
        )
        Stop-IfCancelled
        [void]$CreatedVms.Add($aname)

        if (-not (Wait-MultipassInstanceReady -MultipassCmd $MultipassCmd -InstanceName $aname -TimeoutSeconds $LaunchTimeoutSeconds)) {
            throw "Instance '$aname' did not become ready within ${LaunchTimeoutSeconds}s."
        }
        $registered = Wait-NodeRegistered -MultipassCmd $MultipassCmd -PrimaryServer $PrimaryServer -NodeName $aname -TimeoutSeconds $NodeRegisterTimeoutSeconds -RemoteCmdTimeoutSeconds $RemoteCmdTimeoutSeconds
        if (-not $registered) {
            Write-Warning "Node '$aname' failed to register; refreshing API endpoint and retrying..."
            try {
                $refresh = Refresh-ClusterApiEndpoint -ClusterName $ClusterName -MultipassCmd $MultipassCmd -MaxAttempts 30 -DelaySeconds 2
                if ($refresh -and $refresh.ServerIp) {
                    $serverIP = $refresh.ServerIp
                }
            }
            catch {
                Write-Verbose ("Refresh-ClusterApiEndpoint failed: {0}" -f $_.Exception.Message)
            }
            try {
                $latestIp = Get-InstanceIPv4 -MultipassCmd $MultipassCmd -InstanceName $PrimaryServer
                if ($latestIp) { $serverIP = $latestIp }
            }
            catch {
                Write-Verbose ("Failed to refresh server IP for '{0}': {1}" -f $PrimaryServer, $_.Exception.Message)
            }
            $registered = Wait-NodeRegistered -MultipassCmd $MultipassCmd -PrimaryServer $PrimaryServer -NodeName $aname -TimeoutSeconds $NodeRegisterTimeoutSeconds -RemoteCmdTimeoutSeconds $RemoteCmdTimeoutSeconds
        }
        if (-not $registered) {
            throw "Node '$aname' failed to register within ${NodeRegisterTimeoutSeconds}s."
        }

        if (-not $DisableFlannel) {
            $ready = Wait-NodeReady -MultipassCmd $MultipassCmd -PrimaryServer $PrimaryServer -NodeName $aname -TimeoutSeconds $NodeReadyTimeoutSeconds -RemoteCmdTimeoutSeconds $RemoteCmdTimeoutSeconds
            if (-not $ready) {
                Write-Warning "Node '$aname' failed to reach Ready; refreshing API endpoint and retrying..."
                try {
                    $refresh = Refresh-ClusterApiEndpoint -ClusterName $ClusterName -MultipassCmd $MultipassCmd -MaxAttempts 30 -DelaySeconds 2
                    if ($refresh -and $refresh.ServerIp) {
                        $serverIP = $refresh.ServerIp
                    }
                }
                catch {
                    Write-Verbose ("Refresh-ClusterApiEndpoint failed: {0}" -f $_.Exception.Message)
                }
                $ready = Wait-NodeReady -MultipassCmd $MultipassCmd -PrimaryServer $PrimaryServer -NodeName $aname -TimeoutSeconds $NodeReadyTimeoutSeconds -RemoteCmdTimeoutSeconds $RemoteCmdTimeoutSeconds
            }
            if (-not $ready) {
                throw "Node '$aname' failed to reach Ready within ${NodeReadyTimeoutSeconds}s."
            }
        }
        else {
            Write-Warning "Flannel disabled. Nodes may remain NotReady until you install an external CNI."
        }
        $agents += $aname
    }

    return $agents
}
