function Resolve-StuckStartingInstances {
    param(
        [Parameter(Mandatory=$true)][string]$MultipassCmd,
        [Parameter(Mandatory=$true)][string[]]$InstanceNames
    )

    $forced = @()
    $stuckStarting = @()
    foreach ($name in @($InstanceNames)) {
        if ([string]::IsNullOrWhiteSpace($name)) {
            continue
        }
        try {
            Invoke-Multipass -MultipassCmd $MultipassCmd -MpArgs @("stop", "--force", $name) -AllowNonZero | Out-Null
        }
        catch {
            Write-NonFatalError $_
        }

        $state = $null
        try {
            $list = Get-MultipassListJson -MultipassCmd $MultipassCmd
            if ($list -and $list.list) {
                $vm = $list.list | Where-Object { $_.name -eq $name } | Select-Object -First 1
                if ($vm) {
                    $state = $vm.state
                }
            }
        }
        catch {
            Write-NonFatalError $_
        }

        if ($state -and $state -ne 'Starting') {
            $forced += $name
            continue
        }

        $hvState = Get-HyperVVmState -InstanceName $name
        if ($hvState -and $hvState -ne 'Running') {
            $stuckStarting += $name
        }

        if (Stop-HyperVVmForce -InstanceName $name) {
            $forced += $name
            continue
        }

        Write-Warning "Instance '$name' is still in 'Starting' state after force stop attempts."
    }

    if ($stuckStarting.Count -gt 0) {
        Write-Warning "Multipass still reports 'Starting' while Hyper-V is not running for: $($stuckStarting -join ', ')"
        if (Restart-MultipassServiceIfIdle -MultipassCmd $MultipassCmd) {
            try {
                $listObj = Get-MultipassListJson -MultipassCmd $MultipassCmd
                if ($listObj -and $listObj.list) {
                    foreach ($n in $stuckStarting) {
                        $vm = $listObj.list | Where-Object { $_.name -eq $n } | Select-Object -First 1
                        if ($vm -and $vm.state -ne 'Starting') {
                            $forced += $n
                        }
                    }
                }
            }
            catch {
                Write-NonFatalError $_
            }
        }
        else {
            Write-Warning "Multipass appears out of sync. Try running: Restart-Service multipass"
        }
    }

    if ($forced.Count -gt 0) {
        Start-Sleep -Seconds 2
    }
    return $forced
}

