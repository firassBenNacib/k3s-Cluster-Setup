function Show-StartVmDiagnostics {
    param(
        [Parameter(Mandatory)][string]$InstanceName
    )

    Write-Host ""
    Write-Host "Hyper-V / Multipass diagnostics for '$InstanceName'" -ForegroundColor Yellow

    try {
        $mp = Get-MultipassCmd
        $info = Invoke-Multipass -MultipassCmd $mp -MpArgs @("info", $InstanceName) -AllowNonZero
        if ($info) {
            Write-Host "multipass info:" -ForegroundColor Cyan
            ($info | Out-String).TrimEnd() | ForEach-Object { Write-Host "  $_" }
        }
    }
    catch {
        Write-NonFatalError $_
    }

    try {
        $mem = Get-HostMemoryInfo
        if ($null -ne $mem) {
            $freeGiB = [math]::Round(($mem.FreeBytes / 1GB), 2)
            $totalGiB = [math]::Round(($mem.TotalBytes / 1GB), 2)
            Write-Host "Host memory:" -ForegroundColor Cyan
            Write-Host ("  Free/Total: {0} GiB / {1} GiB" -f $freeGiB, $totalGiB)
        }
    }
    catch {
        Write-NonFatalError $_
    }

    try {
        if (Get-Command -Name Get-VM -ErrorAction SilentlyContinue) {
            $vm = $null
            try {
                $vm = Get-VM -Name $InstanceName -ErrorAction Stop
            }
            catch {
                $vm = Get-VM -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "*$InstanceName*" } | Select-Object -First 1
            }
            if ($vm) {
                Write-Host "Hyper-V VM state:" -ForegroundColor Cyan
                Write-Host ("  Name : {0}" -f $vm.Name)
                Write-Host ("  State: {0}" -f $vm.State)
                Write-Host ("  Status: {0}" -f $vm.Status)
            }
        }
    }
    catch {
        Write-NonFatalError $_
    }

    try {
        $since = (Get-Date).AddMinutes(-15)
        $logs = @(
            'Microsoft-Windows-Hyper-V-VMMS/Admin',
            'Microsoft-Windows-Hyper-V-Worker/Admin'
        )
        $found = $false
        foreach ($ln in $logs) {
            try {
                $ev = Get-WinEvent -FilterHashtable @{ LogName = $ln; StartTime = $since } -ErrorAction Stop |
                    Where-Object { $_.Message -match [regex]::Escape($InstanceName) } |
                    Select-Object -First 5
                if ($ev) {
                    $found = $true
                    Write-Host "Recent Hyper-V events ($ln):" -ForegroundColor Cyan
                    foreach ($e in $ev) {
                        $msg = ($e.Message -replace "\s+", " ").Trim()
                        Write-Host ("  [{0}] {1}" -f $e.TimeCreated.ToString('s'), $msg)
                    }
                }
            }
            catch {
                Write-NonFatalError $_
            }
        }

        if (-not $found) {
            return
        }
    }
    catch {
        Write-NonFatalError $_
    }
}
