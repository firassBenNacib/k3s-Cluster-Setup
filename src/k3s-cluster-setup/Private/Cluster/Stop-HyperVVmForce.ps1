function Stop-HyperVVmForce {
    param([Parameter(Mandatory=$true)][string]$InstanceName)

    if (-not (Get-Command -Name Get-VM -ErrorAction SilentlyContinue)) {
        return $false
    }

    $vm = $null
    try {
        $vm = Get-VM -Name $InstanceName -ErrorAction Stop
    }
    catch {
        try {
            $vm = Get-VM -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "*$InstanceName*" } | Select-Object -First 1
        }
        catch {
            $vm = $null
        }
    }

    if (-not $vm) {
        return $false
    }
    if ($vm.State -eq 'Off') {
        return $true
    }

    try {
        Stop-VM -Name $vm.Name -TurnOff -Force -ErrorAction Stop | Out-Null
        return $true
    }
    catch {
        Write-NonFatalError $_
        return $false
    }
}

