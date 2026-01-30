function Remove-ClusterInstancesBestEffort {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$MultipassCmd,
        [Parameter(Mandatory)][string]$ClusterName,
        [string[]]$InstanceNames = @(),
        [int]$WaitForAppearSeconds = 45,
        [int]$RetryIntervalSeconds = 2
    )

    if ([string]::IsNullOrWhiteSpace($MultipassCmd)) {
        return
    }
    if ([string]::IsNullOrWhiteSpace($ClusterName)) {
        return
    }

    $oldCancel = $script:CancelRequested
    try {
        $script:CancelRequested = $false
    }
    catch {
        Write-NonFatalError $_
    }

    try {
        $isWin = ($env:OS -eq 'Windows_NT') -or ($PSVersionTable.PSEdition -eq 'Desktop')
        $cmp = if ($isWin) {
            [StringComparer]::OrdinalIgnoreCase
        }
        else {
            [StringComparer]::Ordinal
        }

        $targets = New-Object "System.Collections.Generic.HashSet[string]"($cmp)

        $seen = New-Object "System.Collections.Generic.HashSet[string]"($cmp)

        foreach ($n in @($InstanceNames)) {
            if (-not [string]::IsNullOrWhiteSpace($n)) {
                [void]$targets.Add($n)
            }
        }

        $rxNewSrv = '^k3s-srv\d+-' + [regex]::Escape($ClusterName) + '$'
        $rxNewAgt = '^k3s-agt\d+-' + [regex]::Escape($ClusterName) + '$'
        $rxOldSrv = '^k3s-server-' + [regex]::Escape($ClusterName) + '$'
        $rxOldAgt = '^k3s-agent-' + [regex]::Escape($ClusterName) + '-\d+$'

        try {
            Invoke-Multipass -MultipassCmd $MultipassCmd -MpArgs @('wait-ready', '--timeout', '30') -AllowNonZero -TimeoutSeconds 35 | Out-Null
        }
        catch {
            Write-NonFatalError $_
        }

        Add-ClusterTargetsFromList -MultipassCmd $MultipassCmd -Targets $targets -RxNewSrv $rxNewSrv -RxNewAgt $rxNewAgt -RxOldSrv $rxOldSrv -RxOldAgt $rxOldAgt

        $appearDeadline = (Get-Date).AddSeconds([Math]::Max(0, $WaitForAppearSeconds))
        $deadline = (Get-Date).AddSeconds([Math]::Max(0, $WaitForAppearSeconds + 30))

        while ($true) {
            Add-ClusterTargetsFromList -MultipassCmd $MultipassCmd -Targets $targets -RxNewSrv $rxNewSrv -RxNewAgt $rxNewAgt -RxOldSrv $rxOldSrv -RxOldAgt $rxOldAgt

            foreach ($vm in @($targets)) {

                try {
                    Invoke-Multipass -MultipassCmd $MultipassCmd -MpArgs @("stop", "--force", $vm) -AllowNonZero -TimeoutSeconds 30 | Out-Null
                }
                catch {
                    Write-NonFatalError $_
                }
                try {
                    Invoke-Multipass -MultipassCmd $MultipassCmd -MpArgs @("stop", $vm) -AllowNonZero -TimeoutSeconds 30 | Out-Null
                }
                catch {
                    Write-NonFatalError $_
                }

                try {
                    Invoke-Multipass -MultipassCmd $MultipassCmd -MpArgs @("delete", "--purge", $vm) -AllowNonZero -TimeoutSeconds 30 | Out-Null
                }
                catch {
                    try {
                        Invoke-Multipass -MultipassCmd $MultipassCmd -MpArgs @("delete", $vm) -AllowNonZero -TimeoutSeconds 30 | Out-Null
                    }
                    catch {
                        Write-NonFatalError $_
                    }
                }
            }

            $stillThere = @()
            try {
                $listObj2 = Get-MultipassListJson -MultipassCmd $MultipassCmd
                $present = @{}
                foreach ($vm in @($listObj2.list)) {
                    $present[$vm.name] = $vm.state
                }

                foreach ($n in @($targets)) {
                    if ($present.ContainsKey($n)) {
                        [void]$seen.Add($n)
                        if ($present[$n] -ne 'Deleted') {
                            $stillThere += $n
                        }
                        continue
                    }

                    if (-not $seen.Contains($n)) {
                        if ((Get-Date) -lt $appearDeadline) {
                            $stillThere += $n
                        }
                    }
                }
            }
            catch {
                $stillThere = @($targets)
            }

            if ($stillThere.Count -eq 0) {
                break
            }
            if ((Get-Date) -ge $deadline) { break }

            Start-Sleep -Seconds $RetryIntervalSeconds
        }

        try {
            Invoke-Multipass -MultipassCmd $MultipassCmd -MpArgs @('purge') -AllowNonZero -TimeoutSeconds 30 | Out-Null
        }
        catch {
            Write-NonFatalError $_
        }

        try {
            $listObj3 = Get-MultipassListJson -MultipassCmd $MultipassCmd
            $present3 = @{}
            foreach ($vm in @($listObj3.list)) { $present3[$vm.name] = $vm.state }
            $left = @()
            foreach ($n in @($targets)) {
                if ($present3.ContainsKey($n) -and $present3[$n] -ne 'Deleted') { $left += $n }
            }
            if ($left.Count -gt 0) {
                Write-Warning ("Cleanup incomplete; remaining instance(s): {0}" -f ($left -join ', '))
            }
        }
        catch {
            Write-NonFatalError $_
        }
    }
    finally {
        try {
            $script:CancelRequested = $oldCancel
        }
        catch {
            Write-NonFatalError $_
        }
    }
}
