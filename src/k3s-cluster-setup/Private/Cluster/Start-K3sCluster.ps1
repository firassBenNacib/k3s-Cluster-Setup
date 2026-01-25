function Start-K3sCluster {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$ClusterName,
        [Parameter(Mandatory=$false)][string]$MultipassCmd,
        [switch]$Force,
        [switch]$Confirm
    )

    $mp = if ($MultipassCmd) { $MultipassCmd } else { Get-MultipassCmd }
    $inv = Get-ClusterInventory -MultipassCmd $mp

    if (-not ($inv.Clusters.ContainsKey($ClusterName))) {
        throw "Cluster '$ClusterName' not found."
    }

    $c = $inv.Clusters[$ClusterName]
    $vms = @($c.Servers + $c.Agents) | Where-Object { $_ } | Select-Object -Unique

    if (@($vms).Count -eq 0) {
        Write-Warning "Cluster '$ClusterName' has no instances."
        return
    }

    $vmRows = Get-ClusterVmRows -Inventory $inv -VmNames $vms

    $unknown = @($vmRows | Where-Object { $_.State -eq 'Unknown' } | Select-Object -ExpandProperty Name)
    if (@($unknown).Count -gt 0) {
        Write-Warning "Some instances were not found in multipass inventory and will be skipped: $($unknown -join ', ')"
    }

    $starting = @(
        $vmRows |
            Where-Object { $_.State -eq 'Starting' } |
            Select-Object -ExpandProperty Name
    )
    $toStart = @(
        $vmRows |
            Where-Object { $_.State -in @('Stopped','Suspended') } |
            Select-Object -ExpandProperty Name
    )

    if (@($toStart).Count -eq 0 -and @($starting).Count -eq 0) {
        Write-Host "Cluster '$ClusterName' is already running." -ForegroundColor Yellow
        return $false
    }

    $running = @(
        $vmRows |
            Where-Object { $_.State -eq 'Running' } |
            Select-Object -ExpandProperty Name
    )
    if (@($running).Count -gt 0) {
        Write-Host "Skipping already running VMs: $($running -join ', ')" -ForegroundColor DarkGray
    }
    if (@($starting).Count -gt 0) {
        Write-Host "Waiting for starting VMs: $($starting -join ', ')" -ForegroundColor DarkGray
    }

    $startFailed = $false
    if (@($toStart).Count -gt 0) {
        Write-Host "Starting VMs: $($toStart -join ', ')" -ForegroundColor DarkGray
        try {
            Invoke-Multipass -MultipassCmd $mp -MpArgs (@('start') + $toStart) -TimeoutSeconds 60 -AllowNonZero | Out-Null
        }
        catch {
            $startFailed = $true
            Write-Warning "Failed starting cluster '$ClusterName': $($_.Exception.Message)"
        }
    }

    $waitTargets = @(@($toStart) + @($starting)) | Select-Object -Unique
    if (@($waitTargets).Count -gt 0) {
        $failedReady = Wait-MultipassInstancesReady -MultipassCmd $mp -InstanceNames $waitTargets -TimeoutSeconds 180
        if (@($failedReady).Count -gt 0) {
            $startFailed = $true
            Write-Warning "Instances did not become ready: $($failedReady -join ', ')"
            $invStuck = Get-ClusterInventory -MultipassCmd $mp
            $vmRowsStuck = Get-ClusterVmRows -Inventory $invStuck -VmNames $vms
            $stillStarting = @(
                $vmRowsStuck |
                    Where-Object { $_.State -eq 'Starting' } |
                    Select-Object -ExpandProperty Name
            )
            if (@($stillStarting).Count -gt 0) {
                Write-Warning "Instances stuck in Starting; attempting force stop and retry: $($stillStarting -join ', ')"
                foreach ($n in $stillStarting) {
                    Show-StartVmDiagnostics -InstanceName $n
                }
                $forced = Resolve-StuckStartingInstances -MultipassCmd $mp -InstanceNames $stillStarting
                if (@($forced).Count -gt 0) {
                    try {
                        Invoke-Multipass -MultipassCmd $mp -MpArgs (@('start') + $forced) -TimeoutSeconds 60 -AllowNonZero | Out-Null
                        $retryFailed = Wait-MultipassInstancesReady -MultipassCmd $mp -InstanceNames $forced -TimeoutSeconds 180
                        if (@($retryFailed).Count -gt 0) {
                            Write-Warning "Instances still not ready after retry: $($retryFailed -join ', ')"
                        }
                        else {
                            $remaining = @($failedReady | Where-Object { $_ -notin $stillStarting })
                            if (@($remaining).Count -eq 0) {
                                $startFailed = $false
                            }
                        }
                    }
                    catch {
                        Write-Warning "Retry start failed: $($_.Exception.Message)"
                    }
                }
            }
        }
    }

    $invNow = Get-ClusterInventory -MultipassCmd $mp
    $vmRowsNow = Get-ClusterVmRows -Inventory $invNow -VmNames $vms
    $serverNotRunning = @(
        $vmRowsNow |
            Where-Object { ($_.Name -in @($c.Servers)) -and $_.State -ne 'Running' } |
            Select-Object -ExpandProperty Name
    )
    if (@($serverNotRunning).Count -gt 0) {
        Write-Warning "Server instance(s) not running: $($serverNotRunning -join ', ')"
        return $false
    }

    $refreshOk = $true
    try {
        $null = Refresh-ClusterApiEndpoint -ClusterName $ClusterName -MultipassCmd $mp -MaxAttempts 120 -DelaySeconds 2
    }
    catch {
        $refreshOk = $false
        Write-Verbose "Refresh-ClusterApiEndpoint failed for '$ClusterName': $($_.Exception.Message)"
    }

    if ($startFailed -or -not $refreshOk) {
        Write-Warning "Cluster '$ClusterName' start incomplete. Check multipass list for stuck instances."
        return $false
    }

    Write-Host "Cluster '$ClusterName' started." -ForegroundColor Green
    return $true
}

