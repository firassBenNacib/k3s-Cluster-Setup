function Get-HyperVStateSafe {
    param([string]$VmName)
    if ([string]::IsNullOrWhiteSpace($VmName)) {
        return $null
    }
    if (-not (Get-Command -Name Get-VM -ErrorAction SilentlyContinue)) {
        return $null
    }
    try {
        $vm = Get-VM -Name $VmName -ErrorAction Stop
        return [string]$vm.State
    }
    catch {
        try {
            $vm = Get-VM -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "*$VmName*" } | Select-Object -First 1
            if ($vm) {
                return [string]$vm.State
            }
        }
        catch {

        }
    }
    return $null
}
