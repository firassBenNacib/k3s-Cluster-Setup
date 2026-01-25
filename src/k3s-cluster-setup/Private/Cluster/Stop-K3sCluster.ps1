function Stop-K3sCluster {
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

    $starting = @($vmRows | Where-Object { $_.State -eq 'Starting' } | Select-Object -ExpandProperty Name)
    if (@($starting).Count -gt 0) {
        Write-Verbose ("Instances still starting; waiting before stop: {0}" -f ($starting -join ', '))
        $null = Wait-MultipassInstancesReady -MultipassCmd $mp -InstanceNames $starting -TimeoutSeconds 60
        $inv = Get-ClusterInventory -MultipassCmd $mp
        $vmRows = Get-ClusterVmRows -Inventory $inv -VmNames $vms
        $starting = @($vmRows | Where-Object { $_.State -eq 'Starting' } | Select-Object -ExpandProperty Name)
    }

    if (@($starting).Count -gt 0) {
        Write-Verbose ("Instances still starting; attempting force stop: {0}" -f ($starting -join ', '))
        $forced = Resolve-StuckStartingInstances -MultipassCmd $mp -InstanceNames $starting
        if (@($forced).Count -gt 0) {
            $inv = Get-ClusterInventory -MultipassCmd $mp
            $vmRows = Get-ClusterVmRows -Inventory $inv -VmNames $vms
            $starting = @($vmRows | Where-Object { $_.State -eq 'Starting' } | Select-Object -ExpandProperty Name)
        }
        if (@($starting).Count -gt 0) {
            foreach ($n in $starting) {
                Show-StartVmDiagnostics -InstanceName $n
            }
        }
    }

    $toStop = @(
        $vmRows |
            Where-Object { $_.State -notin @('Stopped','Suspended') } |
            Select-Object -ExpandProperty Name
    )

    $stillStarting = @($vmRows | Where-Object { $_.State -eq 'Starting' } | Select-Object -ExpandProperty Name)
    if (@($stillStarting).Count -gt 0) {
        Write-Warning "Instances are still starting and will be skipped: $($stillStarting -join ', ')"
        $toStop = @($toStop | Where-Object { $_ -notin $stillStarting })
    }

    if (@($toStop).Count -eq 0) {
        if (@($stillStarting).Count -gt 0) {
            return $false
        }
        Write-Host "Cluster '$ClusterName' is already stopped." -ForegroundColor Yellow
        return $false
    }

    $skipped = @($vms | Where-Object { $_ -notin $toStop })
    if (@($skipped).Count -gt 0) {
        $skippedStopped = @(
            $vmRows |
                Where-Object { $_.Name -in $skipped -and $_.State -in @('Stopped','Suspended') } |
                Select-Object -ExpandProperty Name
        )
        if (@($skippedStopped).Count -gt 0) {
            Write-Host "Skipping already stopped VMs: $($skippedStopped -join ', ')" -ForegroundColor DarkGray
        }
        $skippedStarting = @(
            $vmRows |
                Where-Object { $_.Name -in $skipped -and $_.State -eq 'Starting' } |
                Select-Object -ExpandProperty Name
        )
        if (@($skippedStarting).Count -gt 0) {
            Write-Host "Skipping still-starting VMs: $($skippedStarting -join ', ')" -ForegroundColor Yellow
        }
    }

    Write-Host "Stopping VMs: $($toStop -join ', ')" -ForegroundColor DarkGray
    try {
        Invoke-Multipass -MultipassCmd $mp -MpArgs (@('stop') + $toStop) -TimeoutSeconds 30 -AllowNonZero | Out-Null
    }
    catch {
        Write-Warning "Failed stopping cluster '$ClusterName': $($_.Exception.Message)"
        return $false
    }

    $invAfter = Get-ClusterInventory -MultipassCmd $mp
    $vmRowsAfter = Get-ClusterVmRows -Inventory $invAfter -VmNames $vms
    $stillRunning = @(
        $vmRowsAfter |
            Where-Object { $_.State -notin @('Stopped','Suspended') } |
            Select-Object -ExpandProperty Name
    )
    if (@($stillRunning).Count -gt 0) {
        Write-Warning "Some instances are still not stopped: $($stillRunning -join ', ')"
        return $false
    }

    Write-Host "Cluster '$ClusterName' stopped." -ForegroundColor Green
    return $true
}

