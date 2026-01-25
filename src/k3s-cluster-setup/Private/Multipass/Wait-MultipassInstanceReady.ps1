function Wait-MultipassInstanceReady {
    param([string]$MultipassCmd, [string]$InstanceName, [int]$TimeoutSeconds)
    Show-CancelHint
    $start = Get-Date
    if (-not $script:MultipassWaitReadyUnsupported) {
        try {
            Invoke-Multipass -MultipassCmd $MultipassCmd -MpArgs @("wait-ready", "--timeout", "60", $InstanceName) | Out-Null
            return $true
        }
        catch {
            $msg = $_.Exception.Message
            if ($msg -match "(?i)unknown command or alias 'wait-ready'") {
                $script:MultipassWaitReadyUnsupported = $true
                $script:MultipassWaitReadyWarned = $true
            }
            else {
                Write-NonFatalError $_
            }
        }
    }
    Stop-IfCancelled

    while (((Get-Date) - $start).TotalSeconds -lt $TimeoutSeconds) {
        Stop-IfCancelled
        try {
            $list = Get-MultipassListJson -MultipassCmd $MultipassCmd
            $vm = $null
            if ($list -and $list.list) {
                $vm = $list.list | Where-Object { $_.name -eq $InstanceName } | Select-Object -First 1
            }
            if (-not $vm) {
                Start-Sleep -Seconds 2; continue
            }
            if ($vm.state -ne 'Running') {
                Start-Sleep -Seconds 2; continue
            }
            Invoke-MpTimeoutBash -MultipassCmd $MultipassCmd -InstanceName $InstanceName -BashCmd "echo ok" -TimeoutSeconds 10 -AllowNonZero | Out-Null
            return $true
        }
        catch {
            Start-Sleep -Seconds 2
        }
    }
    return $false
}
