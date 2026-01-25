function Invoke-K3sClusterCreateServers {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ClusterName,
        [Parameter(Mandatory)][string]$PrimaryServer,
        [string[]]$AdditionalServers = @(),
        [Parameter(Mandatory)][string]$Image,
        [Parameter(Mandatory)][string]$ServerCpu,
        [Parameter(Mandatory)][string]$ServerDisk,
        [Parameter(Mandatory)][string]$ServerMemory,
        [Parameter(Mandatory)][string]$Channel,
        [AllowEmptyString()][string]$K3sVersion,
        [Parameter(Mandatory)][string]$ServerToken,
        [Parameter(Mandatory)][string]$AgentToken,
        [Parameter(Mandatory)][bool]$DisableFlannel,
        [Parameter(Mandatory)][bool]$DisableTraefik,
        [Parameter(Mandatory)][bool]$DisableServiceLB,
        [Parameter(Mandatory)][bool]$DisableMetricsServer,
        [Parameter(Mandatory)][string]$OutputDir,
        [Parameter(Mandatory)][string]$MultipassCmd,
        [Parameter(Mandatory)][int]$LaunchTimeoutSeconds,
        [Parameter(Mandatory)][int]$RemoteCmdTimeoutSeconds,
        [Parameter(Mandatory)][int]$ApiReadyTimeoutSeconds,
        [Parameter(Mandatory)][int]$NodeRegisterTimeoutSeconds,
        [Parameter(Mandatory)][int]$NodeReadyTimeoutSeconds,
        [Parameter(Mandatory)][bool]$UseClusterInit,
        [Parameter(Mandatory)][AllowEmptyCollection()][System.Collections.Generic.List[string]]$CreatedVms,
        [Parameter(Mandatory)][AllowEmptyCollection()][System.Collections.Generic.List[string]]$CreatedFiles,
        [Parameter(Mandatory)][AllowEmptyCollection()][System.Collections.Generic.List[string]]$PlannedVms
    )

    $servers = @()
    $serverIP = ""
    $server1 = $PrimaryServer

    Stop-IfCancelled
    Write-Host ""

    $serverExec1 = New-K3sServerExecArgs -IsInitServer $true -UseClusterInit $UseClusterInit -DisableFlannel $DisableFlannel `
        -DisableTraefik $DisableTraefik -DisableServiceLB $DisableServiceLB -DisableMetricsServer $DisableMetricsServer -JoinServerIP ""

    $ci1 = New-CloudInitTemplate -Hostname $server1 -Channel $Channel -K3sVersion $K3sVersion -ServerToken $ServerToken -AgentToken $AgentToken `
        -ServerIP "" -IsAgent:$false -ServerExec $serverExec1 -AgentExec ""

    $ci1File = Join-Path $OutputDir ("{0}-srv1-cloud-init.yaml" -f $ClusterName)
    Write-Utf8File -Path $ci1File -Content $ci1
    [void]$CreatedFiles.Add($ci1File)

    Write-Host ""
    Write-Host "Creating initial server: $server1" -ForegroundColor Green

    [void]$PlannedVms.Add($server1)
    Invoke-MultipassLaunchResilient -MultipassCmd $MultipassCmd -InstanceName $server1 -MpArgs @(
        "launch", "--timeout", $LaunchTimeoutSeconds.ToString(),
        "--cpus", $ServerCpu, "--disk", $ServerDisk, "--memory", $ServerMemory,
        $Image, "--name", $server1, "--cloud-init", $ci1File
    )
    Stop-IfCancelled
    [void]$CreatedVms.Add($server1)
    $servers += $server1

    if (-not (Wait-MultipassInstanceReady -MultipassCmd $MultipassCmd -InstanceName $server1 -TimeoutSeconds $LaunchTimeoutSeconds)) {
        Write-Warning "'$server1' did not pass readiness checks in time; continuing to wait for k3s API..."
    }
    if (-not (Wait-K3sApiReady -MultipassCmd $MultipassCmd -ServerInstance $server1 -TimeoutSeconds $ApiReadyTimeoutSeconds -RemoteCmdTimeoutSeconds $RemoteCmdTimeoutSeconds)) {
        throw "k3s API not ready on '$server1' within ${ApiReadyTimeoutSeconds}s."
    }

    $serverIP = Get-InstanceIPv4 -MultipassCmd $MultipassCmd -InstanceName $server1
    Write-Host "Server IP: $serverIP" -ForegroundColor Green

    if (@($AdditionalServers).Count -gt 0) {
        Write-Host ""
        Write-Host ("Creating {0} additional server(s)..." -f @($AdditionalServers).Count) -ForegroundColor Green
        for ($i = 0; $i -lt @($AdditionalServers).Count; $i++) {
            Stop-IfCancelled
            $sname = $AdditionalServers[$i]
            $serverIndex = $i + 2
            $sexec = New-K3sServerExecArgs -IsInitServer $false -UseClusterInit $UseClusterInit -DisableFlannel $DisableFlannel `
                -DisableTraefik $DisableTraefik -DisableServiceLB $DisableServiceLB -DisableMetricsServer $DisableMetricsServer -JoinServerIP $serverIP

            $sci = New-CloudInitTemplate -Hostname $sname -Channel $Channel -K3sVersion $K3sVersion -ServerToken $ServerToken -AgentToken $AgentToken `
                -ServerIP "" -IsAgent:$false -ServerExec $sexec -AgentExec ""

            $sciFile = Join-Path $OutputDir ("{0}-srv{1}-cloud-init.yaml" -f $ClusterName, $serverIndex)
            Write-Utf8File -Path $sciFile -Content $sci
            [void]$CreatedFiles.Add($sciFile)

            Write-Host "Creating additional server: $sname" -ForegroundColor Green
            [void]$PlannedVms.Add($sname)
            Invoke-MultipassLaunchResilient -MultipassCmd $MultipassCmd -InstanceName $sname -MpArgs @(
                "launch", "--timeout", $LaunchTimeoutSeconds.ToString(),
                "--cpus", $ServerCpu, "--disk", $ServerDisk, "--memory", $ServerMemory,
                $Image, "--name", $sname, "--cloud-init", $sciFile
            )
            Stop-IfCancelled
            [void]$CreatedVms.Add($sname)

            if (-not (Wait-MultipassInstanceReady -MultipassCmd $MultipassCmd -InstanceName $sname -TimeoutSeconds $LaunchTimeoutSeconds)) {
                throw "Instance '$sname' did not become ready within ${LaunchTimeoutSeconds}s."
            }
            if (-not (Wait-NodeRegistered -MultipassCmd $MultipassCmd -PrimaryServer $server1 -NodeName $sname -TimeoutSeconds $NodeRegisterTimeoutSeconds -RemoteCmdTimeoutSeconds $RemoteCmdTimeoutSeconds)) {
                throw "Node '$sname' failed to register within ${NodeRegisterTimeoutSeconds}s."
            }
            if (-not $DisableFlannel) {
                if (-not (Wait-NodeReady -MultipassCmd $MultipassCmd -PrimaryServer $server1 -NodeName $sname -TimeoutSeconds $NodeReadyTimeoutSeconds -RemoteCmdTimeoutSeconds $RemoteCmdTimeoutSeconds)) {
                    throw "Node '$sname' failed to reach Ready within ${NodeReadyTimeoutSeconds}s."
                }
            }
            $servers += $sname
        }
    }

    return [pscustomobject]@{
        Servers  = $servers
        ServerIP = $serverIP
    }
}
