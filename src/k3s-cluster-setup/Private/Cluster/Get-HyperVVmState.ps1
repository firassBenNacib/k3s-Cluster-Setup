function Get-HyperVVmState {
    param([Parameter(Mandatory=$true)][string]$InstanceName)

    if (-not (Get-Command -Name Get-VM -ErrorAction SilentlyContinue)) {
        return $null
    }
    try {
        $vm = Get-VM -Name $InstanceName -ErrorAction Stop
        return [string]$vm.State
    }
    catch {
        try {
            $vm = Get-VM -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "*$InstanceName*" } | Select-Object -First 1
            if ($vm) {
                return [string]$vm.State
            }
        }
        catch {
            Write-NonFatalError $_
        }
    }
    return $null
}

