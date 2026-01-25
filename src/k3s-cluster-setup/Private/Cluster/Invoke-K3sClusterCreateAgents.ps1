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
    for ($i = 0; $i -lt @($AgentNames).Count; $i++) {
        Stop-IfCancelled
        $aname = $AgentNames[$i]
        $agentIndex = $i + 1
        $aci = New-CloudInitTemplate -Hostname $aname -Channel $Channel -K3sVersion $K3sVersion -ServerToken $ServerToken -AgentToken $AgentToken `
            -ServerIP $ServerIP -IsAgent:$true -ServerExec "" -AgentExec "agent"

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
        if (-not (Wait-NodeRegistered -MultipassCmd $MultipassCmd -PrimaryServer $PrimaryServer -NodeName $aname -TimeoutSeconds $NodeRegisterTimeoutSeconds -RemoteCmdTimeoutSeconds $RemoteCmdTimeoutSeconds)) {
            throw "Node '$aname' failed to register within ${NodeRegisterTimeoutSeconds}s."
        }

        if (-not $DisableFlannel) {
            if (-not (Wait-NodeReady -MultipassCmd $MultipassCmd -PrimaryServer $PrimaryServer -NodeName $aname -TimeoutSeconds $NodeReadyTimeoutSeconds -RemoteCmdTimeoutSeconds $RemoteCmdTimeoutSeconds)) {
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
